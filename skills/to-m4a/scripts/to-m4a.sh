#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BITRATE=48000
MAX_MINUTES=180
INPUT=""
OUTPUT=""

usage() {
	cat <<'USAGE'
사용법: to-m4a.sh <녹화 파일> [-o <출력.m4a>] [--max-minutes <분>]

영상에서 음성만 뽑아 모노 16kHz AAC 48kbps m4a를 만든다. 클로바노트가 받는 형식이다.
출력을 주지 않으면 입력 옆에 같은 이름으로 만든다. 이미 있는 파일은 덮어쓰지 않는다.
길이가 --max-minutes(기본 180, 클로바노트 한도)를 넘으면 이름-1.m4a, 이름-2.m4a로 나눈다.
USAGE
}

fail() {
	echo "오류: $*" >&2
	exit 1
}

human_size() {
	awk -v b="$(stat -f%z "$1")" 'BEGIN {
		if (b >= 1073741824) printf "%.1fGB", b / 1073741824;
		else if (b >= 1048576) printf "%.1fMB", b / 1048576;
		else printf "%.0fKB", b / 1024 }'
}

while [ $# -gt 0 ]; do
	case "$1" in
		-o) [ $# -ge 2 ] || fail "-o 뒤에 출력 경로가 필요하다"; OUTPUT="$2"; shift 2 ;;
		--max-minutes) [ $# -ge 2 ] || fail "--max-minutes 뒤에 분이 필요하다"; MAX_MINUTES="$2"; shift 2 ;;
		-h | --help) usage; exit 0 ;;
		-*) usage >&2; fail "모르는 옵션: $1" ;;
		*) [ -z "$INPUT" ] || fail "입력은 하나만 받는다. 여러 파일이면 한 번씩 부른다"; INPUT="$1"; shift ;;
	esac
done

[ -n "$INPUT" ] || { usage >&2; exit 2; }
[ -f "$INPUT" ] || fail "파일이 없다: $INPUT"
case "$MAX_MINUTES" in '' | *[!0-9]* | 0) fail "--max-minutes는 1 이상의 정수다: $MAX_MINUTES" ;; esac

for tool in afconvert afinfo python3; do
	command -v "$tool" >/dev/null || fail "$tool 이 없다. macOS 내장 도구라 다른 OS에서는 돌지 않는다"
done
python3 -c "import numpy" 2>/dev/null || fail "python3에 numpy가 없다. which python3로 어느 python3가 잡혔는지 본다. Xcode의 python3에는 numpy가 있다"

[ -n "$OUTPUT" ] || OUTPUT="${INPUT%.*}.m4a"
case "$OUTPUT" in *.m4a) ;; *) fail "출력 이름은 .m4a로 끝나야 한다: $OUTPUT" ;; esac
[ ! -e "$OUTPUT" ] || fail "이미 있다. 덮어쓰지 않는다: $OUTPUT"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/to-m4a.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

echo "== 입력"
echo "$INPUT ($(human_size "$INPUT"))"
if ! afinfo "$INPUT" >"$TMP/afinfo.txt" 2>&1; then
	cat "$TMP/afinfo.txt" >&2
	fail "오디오 트랙을 읽지 못했다. 소리가 없는 녹화이거나 지원하지 않는 형식이다"
fi
grep -E "Data format|estimated duration" "$TMP/afinfo.txt" | sed 's/^ *//'

echo
echo "== 1단계: PCM 16kHz WAV로 디코드"
afconvert -f WAVE -d LEI16@16000 "$INPUT" "$TMP/src.wav"
echo "완료 ($(human_size "$TMP/src.wav"))"

echo
echo "== 2단계: 채널 분석과 모노 믹스"
python3 "$SCRIPT_DIR/mix.py" "$TMP/src.wav" "$TMP" "$((MAX_MINUTES * 60))"

COUNT=0
while [ -f "$TMP/part-$((COUNT + 1)).wav" ]; do COUNT=$((COUNT + 1)); done
[ "$COUNT" -ge 1 ] || fail "믹스 결과가 없다"

target_for() {
	if [ "$COUNT" -eq 1 ]; then echo "$OUTPUT"; else echo "${OUTPUT%.m4a}-$1.m4a"; fi
}

i=1
while [ "$i" -le "$COUNT" ]; do
	[ ! -e "$(target_for "$i")" ] || fail "이미 있다. 덮어쓰지 않는다: $(target_for "$i")"
	i=$((i + 1))
done

echo
echo "== 3단계: AAC ${BITRATE}bps m4a 인코딩"
i=1
while [ "$i" -le "$COUNT" ]; do
	afconvert -f m4af -d aac -b "$BITRATE" -q 127 "$TMP/part-$i.wav" "$(target_for "$i")"
	echo "$(target_for "$i") ($(human_size "$(target_for "$i")"))"
	i=$((i + 1))
done

echo
echo "== 4단계: 결과를 다시 디코드해 확인"
TOTAL_BYTES=0
i=1
while [ "$i" -le "$COUNT" ]; do
	afconvert -f WAVE -d LEI16 "$(target_for "$i")" "$TMP/check.wav"
	printf '%s: ' "$(basename "$(target_for "$i")")"
	python3 "$SCRIPT_DIR/check.py" "$TMP/check.wav"
	TOTAL_BYTES=$((TOTAL_BYTES + $(stat -f%z "$(target_for "$i")")))
	i=$((i + 1))
done

echo
echo "== 결과"
echo "원본 $(human_size "$INPUT") 에서 결과 $(awk -v b="$TOTAL_BYTES" 'BEGIN { printf "%.1fMB", b / 1048576 }') 로 줄었다 ($(awk -v a="$(stat -f%z "$INPUT")" -v b="$TOTAL_BYTES" 'BEGIN { printf "%.2f", b / a * 100 }')%). 원본은 그대로 두었다"
echo "클로바노트에 올릴 파일:"
i=1
while [ "$i" -le "$COUNT" ]; do
	echo "  $(target_for "$i")"
	i=$((i + 1))
done
