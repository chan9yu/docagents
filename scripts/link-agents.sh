#!/usr/bin/env bash
#
# link-agents. `~/.agents` 본문을 사용자 설정 디렉터리에 심링크.
#
# 룰과 스킬 본문은 `~/.agents` 한 곳에만 둔다. 도구는 자기 설정 디렉터리에서
# 링크로 같은 파일을 읽는다. 도구가 늘어도 고칠 본문이 한 곳에 남는다.
#
# - 스킬은 디렉터리 단위. `~/.agents/skills/{이름}/` 을 `~/.claude/skills/{이름}` 으로 링크
# - 룰은 파일 단위. `~/.agents/rules/{이름}.md` 를 `~/.claude/rules/{이름}.md` 로 링크
# - 링크가 가리키는 곳이 다르면 다시 만든다
# - `~/.agents` 에서 사라진 항목의 링크는 지운다
#
# 새 도구를 붙일 때는 아래 TARGETS 에 디렉터리를 추가한다.
#
# Usage:
#   bash ~/.agents/scripts/link-agents.sh
#   bash ~/.agents/scripts/link-agents.sh --dry-run   # 무엇이 바뀔지만 보여준다
#
# macOS bash 3.2 호환. associative array 를 쓰지 않는다.

set -euo pipefail

DRY_RUN=0
for arg in "$@"; do
	case "$arg" in
		--dry-run) DRY_RUN=1 ;;
		-h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "ERROR: 모르는 옵션 $arg" >&2; exit 1 ;;
	esac
done

AGENTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Claude Code 는 CLAUDE_CONFIG_DIR 로 설정 위치를 옮길 수 있다. statusLine 등
# 다른 설정도 이 변수를 따르므로 여기서도 존중한다.
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

SKILL_TARGETS="$CLAUDE_DIR/skills"
RULE_TARGETS="$CLAUDE_DIR/rules"

# Claude Code 가 스스로 만들고 지우는 자리. 본문이 갈라지는 문제와 무관하니
# 검사에서 뺀다. synced 는 claude.ai 에서 켠 스킬이 내려오는 곳이다.
IGNORED_ENTRIES=" synced .trash "

# 홈 경로를 물결표로 줄여 출력한다.
pretty() {
	case "$1" in
		"$HOME"/*) echo "~${1#"$HOME"}" ;;
		*) echo "$1" ;;
	esac
}

run() {
	[ "$DRY_RUN" -eq 1 ] && return 0
	"$@"
}

# `~/.agents` 와 설정 디렉터리가 같은 부모 아래 있으면 상대 경로로 건다.
# 홈 경로가 기기마다 달라도 링크가 살아 있다. 아니면 절대 경로로 건다.
link_target() {
	local subdir="$1" name="$2"

	if [ "$(dirname "$CLAUDE_DIR")" = "$(dirname "$AGENTS_DIR")" ]; then
		echo "../../$(basename "$AGENTS_DIR")/$subdir/$name"
	else
		echo "$AGENTS_DIR/$subdir/$name"
	fi
}

# 예전에는 rules 디렉터리 자체를 통째로 링크했다. 파일 단위로 바꾸려면 그
# 링크를 먼저 걷어낸다. 링크만 지우므로 `~/.agents` 의 본문은 그대로다.
unlink_dir_link() {
	local dir="$1"

	[ -L "$dir" ] || return 0

	echo "정리: $(pretty "$dir") 디렉터리 링크를 걷어내고 파일 단위로 바꿉니다."
	run rm "$dir"
}

# 설정 디렉터리에 링크가 아닌 것이 있으면 알린다. 실재 파일을 여기 두면
# Claude Code 는 읽지만 다른 도구는 못 읽어 본문이 갈라진다.
#
# 프로젝트와 달리 홈은 이 스크립트만 쓰는 자리가 아니다. 멈추면 나머지 링크가
# 통째로 밀리므로 알리고 계속한다. 발견한 개수를 UNMANAGED 에 쌓는다.
UNMANAGED=0
warn_real_entries() {
	local target_dir="$1"
	local entry name

	# 디렉터리 자체가 링크면 걷어낼 대상이다. 미리보기에서는 아직 남아 있어
	# 안을 들여다보면 `~/.agents` 본문을 실재 파일로 잘못 신고한다.
	[ -L "$target_dir" ] && return 0
	[ -d "$target_dir" ] || return 0

	for entry in "$target_dir"/*; do
		[ -e "$entry" ] || continue
		[ -L "$entry" ] && continue

		name="$(basename "$entry")"
		case "$IGNORED_ENTRIES" in
			*" $name "*) continue ;;
		esac

		echo "경고: $(pretty "$entry") 가 심링크가 아닙니다." >&2
		UNMANAGED=$((UNMANAGED + 1))
	done
}

# 링크를 만든다. 이미 같은 곳을 가리키면 그대로 둔다.
ensure_link() {
	local link_path="$1"
	local target="$2"

	if [ -L "$link_path" ]; then
		if [ "$(readlink "$link_path")" = "$target" ]; then
			return 0
		fi
		run rm "$link_path"
	fi

	run ln -s "$target" "$link_path"
	echo "연결: $(pretty "$link_path") -> $target"
}

# `~/.agents` 를 가리키는데 본문이 사라진 링크를 지운다.
prune_stale() {
	local target_dir="$1"
	local valid="$2"
	local link name

	[ -d "$target_dir" ] || return 0

	for link in "$target_dir"/*; do
		[ -L "$link" ] || continue

		case "$(readlink "$link")" in
			*"/.agents/"*|*"$(basename "$AGENTS_DIR")/"*) ;;
			*) continue ;;
		esac

		name="$(basename "$link")"
		case "$valid" in
			*" $name "*) continue ;;
		esac

		run rm "$link"
		echo "삭제: $(pretty "$target_dir")/$name"
	done
}

[ "$DRY_RUN" -eq 1 ] && echo "미리보기입니다. 파일을 건드리지 않습니다."
echo "본문: $(pretty "$AGENTS_DIR")"
echo "설정: $(pretty "$CLAUDE_DIR")"
echo

unlink_dir_link "$RULE_TARGETS"

for target in $SKILL_TARGETS $RULE_TARGETS; do
	warn_real_entries "$target"
done

# 스킬은 디렉터리 단위로 링크한다.
skill_names=" "
for skill_dir in "$AGENTS_DIR"/skills/*/; do
	[ -d "$skill_dir" ] || continue

	name="$(basename "$skill_dir")"
	skill_names="$skill_names$name "

	for target in $SKILL_TARGETS; do
		run mkdir -p "$target"
		ensure_link "$target/$name" "$(link_target skills "$name")"
	done
done

# 룰은 파일 단위로 링크한다. `~/.agents/rules/` 밖의 문서는 룰이 아니라 대상이 아니다.
rule_names=" "
for rule_md in "$AGENTS_DIR"/rules/*.md; do
	[ -f "$rule_md" ] || continue

	name="$(basename "$rule_md")"
	rule_names="$rule_names$name "

	for target in $RULE_TARGETS; do
		run mkdir -p "$target"
		ensure_link "$target/$name" "$(link_target rules "$name")"
	done
done

for target in $SKILL_TARGETS; do
	prune_stale "$target" "$skill_names"
done

for target in $RULE_TARGETS; do
	prune_stale "$target" "$rule_names"
done

skill_count="$(echo "$skill_names" | wc -w | tr -d ' ')"
rule_count="$(echo "$rule_names" | wc -w | tr -d ' ')"

echo
echo "link-agents 완료. 룰 ${rule_count}개, 스킬 ${skill_count}개 동기화."

if [ "$UNMANAGED" -gt 0 ]; then
	echo
	echo "심링크가 아닌 항목 ${UNMANAGED}개를 그대로 두었습니다."
	echo "다른 도구와 함께 쓰려면 본문을 $(pretty "$AGENTS_DIR") 로 옮기고 다시 실행하세요."
fi
