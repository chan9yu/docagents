# dotagents

여러 AI 코딩 에이전트가 공유하는 스킬·룰 저장소

Claude Code, Cursor, Codex 등 각 에이전트의 설정 디렉토리는 이곳을 심볼릭 링크로 참조한다.
실제 파일은 `~/.agents/`에만 존재하므로, 한 번 수정하면 모든 에이전트에 반영된다.

## 구조

```
.agents/
├── skills/              # 에이전트 스킬 (10개)
├── rules/               # 언어·도메인별 코딩 규칙
└── .skill-lock.json     # 스킬 설치 출처·버전 해시 추적
```

## 구성 요약

**skills/** — `npx skills`로 설치한 GitHub 스킬.

| 스킬                 | 용도                                          |
| -------------------- | --------------------------------------------- |
| `caveman`            | 원시인 말투로 출력 토큰 65% 절감              |
| `code-review-skill`  | 20+ 언어·프레임워크 코드 리뷰 가이드          |
| `context-mode`       | 대용량 출력을 서브에이전트로 처리해 컨텍스트 절약 |
| `find-skills`        | 스킬 검색·설치                                |
| `grill-me`           | 계획·설계를 압박 인터뷰로 검증                |
| `handoff`            | 대화를 인수인계 문서로 압축                   |
| `karpathy-guidelines`| LLM 코딩 실수(과잉 구현·광범위 수정) 방지     |
| `playwright-skill`   | 브라우저 자동화·테스트                        |
| `skill-creator`      | 스킬 생성·개선·성능 측정                      |
| `ui-ux-pro-max`      | UI/UX 디자인 DB (스타일·팔레트·타이포그래피)  |

**rules/** — frontmatter의 `paths` glob으로 적용 대상을 지정하는 코딩 규칙.

- `typescript.md` — strict 모드, `import type` 구분, `any`·`!` 금지, 네이밍 컨벤션(역할 접미사), 클래스 멤버 순서

**.skill-lock.json** — 스킬별 GitHub 출처, 경로, 폴더 해시, 설치·갱신 시각을 기록한다. `npx skills check`가 이 해시로 업데이트 여부를 판단한다.

## 사용법

### 1. 저장소 클론

```bash
git clone https://github.com/<username>/dotagents.git ~/.agents
```

### 2. 에이전트 디렉토리에 링크

Claude Code 기준. 홈 디렉토리 경로에 무관하도록 상대 경로로 건다.

```bash
mkdir -p ~/.claude/skills
for skill in ~/.agents/skills/*/; do
  ln -sfn "../../.agents/skills/$(basename "$skill")" ~/.claude/skills/
done
ln -sfn ../.agents/rules ~/.claude/rules
```

### 3. 스킬 관리

```bash
npx skills find <query>          # 검색
npx skills add <owner/repo> -g   # 전역 설치
npx skills check                 # 업데이트 확인
npx skills update                # 전체 갱신
```

설치 후 `skills/`와 `.skill-lock.json` 변경분을 커밋한다.

## 요구 사항

- Node.js (`npx skills` 실행용)
- 심볼릭 링크를 지원하는 파일 시스템
