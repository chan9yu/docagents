"""16비트 PCM WAV의 길이와 음량을 한 줄로 찍는다. 변환 결과를 다시 디코드해 확인하는 데 쓴다.

사용법: python3 check.py <파일.wav>
"""

import sys

import numpy as np

sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))
from mix import SILENCE_RMS, db, open_pcm


def main():
    pcm, rate = open_pcm(sys.argv[1])
    x = pcm[:, 0].astype(np.float32) / 32768.0
    whole = x[: (len(x) // rate) * rate].reshape(-1, rate)
    active = (np.sqrt((whole * whole).mean(axis=1)) > SILENCE_RMS).mean()
    print(
        f"{pcm.shape[1]}채널 {rate}Hz, 길이 {len(x) / rate / 60:.1f}분, "
        f"RMS {db(np.sqrt((x * x).mean())):.1f} dBFS, 피크 {db(np.abs(x).max()):.1f} dBFS, "
        f"소리 있는 초 {active * 100:.1f}%"
    )


if __name__ == "__main__":
    main()
