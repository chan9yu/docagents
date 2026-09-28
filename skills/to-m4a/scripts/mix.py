"""16비트 PCM WAV를 읽어 소리 있는 채널만 골라 모노 WAV로 쓴다.

사용법: python3 mix.py <입력.wav> <출력 폴더> <조각 최대 초>

채널별 RMS를 재고 가장 큰 채널 기준 20dB 안에 드는 채널만 평균해 섞는다.
피크를 -1dBFS로 맞추고 길이가 조각 최대 초를 넘으면 part-1.wav, part-2.wav로 나눠 쓴다.
자르는 자리는 경계 앞 60초 안에서 가장 조용한 초다.
"""

import struct
import sys
import wave
from pathlib import Path

import numpy as np

SILENCE_RMS = 0.002
KEEP_RATIO = 0.1
TARGET_PEAK = 0.89
MAX_GAIN = 20.0
CUT_SEARCH_SECONDS = 60


def open_pcm(path):
    with open(path, "rb") as f:
        head = f.read(12)
        if head[:4] != b"RIFF" or head[8:12] != b"WAVE":
            raise SystemExit(f"WAV 파일이 아니다: {path}")
        channels = rate = bits = None
        while True:
            chunk = f.read(8)
            if len(chunk) < 8:
                raise SystemExit(f"data 청크를 찾지 못했다: {path}")
            cid, size = chunk[:4], struct.unpack("<I", chunk[4:])[0]
            if cid == b"fmt ":
                fmt = f.read(size)
                channels, rate = struct.unpack("<HI", fmt[2:8])
                bits = struct.unpack("<H", fmt[14:16])[0]
            elif cid == b"data":
                if bits != 16:
                    raise SystemExit(f"16비트 PCM만 다룬다. 지금은 {bits}비트다")
                frames = size // (channels * 2)
                pcm = np.memmap(path, dtype="<i2", mode="r", offset=f.tell(), shape=(frames, channels))
                return pcm, rate
            else:
                f.seek(size + (size & 1), 1)


def db(x):
    return -120.0 if x <= 0 else 20 * np.log10(x)


def analyze_channels(pcm, rate):
    frames, ch = pcm.shape
    win = rate
    sumsq = np.zeros(ch)
    peak = np.zeros(ch)
    active = np.zeros(ch)
    nwin = 0
    for s in range(0, frames - win + 1, win):
        blk = pcm[s : s + win].astype(np.float32) / 32768.0
        sumsq += (blk * blk).sum(axis=0)
        peak = np.maximum(peak, np.abs(blk).max(axis=0))
        active += np.sqrt((blk * blk).mean(axis=0)) > SILENCE_RMS
        nwin += 1
    if nwin == 0:
        raise SystemExit("1초가 안 되는 파일이다")
    rms = np.sqrt(sumsq / (nwin * win))
    return rms, peak, active / nwin


def mix_stats(pcm, rate, use):
    frames = pcm.shape[0]
    win = rate
    sec_rms = []
    mixpeak = 0.0
    for s in range(0, frames, win):
        blk = pcm[s : s + win][:, use].astype(np.float32).mean(axis=1) / 32768.0
        mixpeak = max(mixpeak, float(np.abs(blk).max()))
        sec_rms.append(float(np.sqrt((blk * blk).mean())))
    return mixpeak, np.array(sec_rms)


def cut_points(total_seconds, max_seconds, sec_rms):
    cuts = []
    boundary = max_seconds
    search = min(CUT_SEARCH_SECONDS, max_seconds // 2)
    while boundary < total_seconds:
        lo = max(cuts[-1] + 1 if cuts else 0, boundary - search)
        quietest = lo + int(np.argmin(sec_rms[lo:boundary]))
        cuts.append(quietest)
        boundary = quietest + max_seconds
    return cuts


def write_parts(pcm, rate, use, gain, cuts, out_dir):
    frames = pcm.shape[0]
    edges = [0] + [c * rate for c in cuts] + [frames]
    written = []
    for index, (start, end) in enumerate(zip(edges, edges[1:]), start=1):
        path = out_dir / f"part-{index}.wav"
        with wave.open(str(path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            for s in range(start, end, rate):
                blk = pcm[s : min(s + rate, end)][:, use].astype(np.float32).mean(axis=1) * gain
                w.writeframes(np.clip(np.round(blk), -32768, 32767).astype("<i2").tobytes())
        written.append((path, (end - start) / rate))
    return written


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    src, out_dir, max_seconds = sys.argv[1], Path(sys.argv[2]), int(sys.argv[3])
    pcm, rate = open_pcm(src)
    frames, ch = pcm.shape
    total_seconds = frames // rate
    print(f"입력: {ch}채널 {rate}Hz {frames / rate / 60:.1f}분")

    rms, peak, active = analyze_channels(pcm, rate)
    if rms.max() <= 0:
        raise SystemExit("모든 채널이 무음이다. 음성 트랙이 비어 있는 녹화다")

    print("채널  RMS(dBFS)  피크(dBFS)  소리 있는 초")
    for i in range(ch):
        print(f"{i:>4} {db(rms[i]):>9.1f} {db(peak[i]):>10.1f} {active[i] * 100:>11.1f}%")
    use = [i for i in range(ch) if rms[i] >= rms.max() * KEEP_RATIO]
    dropped = ch - len(use)
    note = f". 무음이거나 20dB 넘게 작은 채널 {dropped}개는 뺐다" if dropped else ""
    print(f"섞는 채널: {use}{note}")

    mixpeak, sec_rms = mix_stats(pcm, rate, use)
    gain = min(TARGET_PEAK / mixpeak, MAX_GAIN)
    print(f"믹스 피크 {db(mixpeak):.1f} dBFS, 게인 {20 * np.log10(gain):+.1f} dB")

    cuts = cut_points(total_seconds, max_seconds, sec_rms)
    parts = write_parts(pcm, rate, use, gain, cuts, out_dir)
    if len(parts) > 1:
        print(f"{max_seconds // 60}분을 넘어 {len(parts)}조각으로 나눴다. 자른 자리는 경계 앞 {CUT_SEARCH_SECONDS}초 안에서 가장 조용한 초다")
        for path, seconds in parts:
            print(f"  {path.name}: {seconds / 60:.1f}분")


if __name__ == "__main__":
    main()
