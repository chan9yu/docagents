# docagents

여러 AI 코딩 에이전트가 공유하는 스킬과 룰 저장소

Claude Code, Cursor, Codex 등 각 에이전트의 설정 디렉토리는 이곳을 심볼릭 링크로 참조한다.
실제 파일은 `~/.agents/`에만 존재하므로, 한 번 수정하면 모든 에이전트에 반영된다.

## 구조

```
.agents/
├── skills/              # 에이전트 스킬 (15개)
├── rules/               # 언어와 도메인별 코딩 규칙 (7개)
├── scripts/
│   └── link-agents.sh   # 설정 디렉토리에 링크 생성
└── .skill-lock.json     # 스킬 설치 출처와 버전 해시 추적
```

## 구성 요약

### skills

`npx skills`로 설치한 것과 직접 만든 것이 섞여 있다.

| 스킬                   | 용도                                                       | 출처   |
| ---------------------- | ---------------------------------------------------------- | ------ |
| `caveman`              | 원시인 말투로 출력 토큰 65% 절감                           | 설치   |
| `code-review-skill`    | 20개 넘는 언어와 프레임워크의 코드 리뷰 가이드             | 설치   |
| `computer-use`         | 접근성 트리와 스크린샷으로 데스크톱 앱 창을 읽고 조작      | 설치   |
| `context-mode`         | 대용량 출력을 서브에이전트로 처리해 컨텍스트 절약          | 설치   |
| `find-skills`          | 스킬 검색과 설치                                           | 설치   |
| `frontend-fundamentals`| 가독성과 예측 가능성, 응집도, 결합도로 프론트엔드 코드 진단 | 직접   |
| `grill-me`             | 계획과 설계를 압박 인터뷰로 검증                           | 설치   |
| `handoff`              | 대화를 인수인계 문서로 압축                                | 설치   |
| `karpathy-guidelines`  | LLM 코딩 실수(과잉 구현, 광범위 수정) 방지                 | 설치   |
| `orca-cli`             | Orca 워크트리와 터미널, 내장 브라우저 조작                 | 설치   |
| `orchestration`        | 멀티 에이전트 조율. 태스크 디스패치와 감독 루프            | 설치   |
| `playwright-skill`     | 브라우저 자동화와 테스트                                   | 설치   |
| `radio-system-design`  | 코드 작성 전 프론트엔드 기능을 RADIO 5단계로 설계          | 직접   |
| `skill-creator`        | 스킬 생성과 개선, 성능 측정                                | 설치   |
| `ui-ux-pro-max`        | UI/UX 디자인 DB (스타일, 팔레트, 타이포그래피)             | 설치   |

### rules

모든 프로젝트에 적용되는 범용 규칙이다. 프로젝트 고유 설정값과 경로, 사내 용어는 담지 않는다. 그런 것은 각 저장소의 `.agents/rules/`가 같은 이름으로 갖고 어긋나면 저장소 쪽이 이긴다.

| 룰                 | 내용                                                        |
| ------------------ | ----------------------------------------------------------- |
| `autonomy.md`      | 사용자 확인이 필요한 변경, 금지 표현, 99% 확신, 커밋 시점   |
| `change-process.md`| 구현 전 확인, 게이트 순서, 3회 반복 실패 시 롤백            |
| `code-style.md`    | 근접성과 빈 줄, 매직 넘버, 복잡한 조건, 시간과 식별자 정규화 |
| `comments.md`      | 총량이 먼저다. 타입 선언 안과 선언부에 쓰고 본문에는 안 쓴다 |
| `git-workflow.md`  | 커밋 분할, 강제 푸시, 금지 패턴, 포맷터 훅의 MM 함정        |
| `testing.md`       | TDD 원칙, mock 정책, flaky 처리, 금지 패턴                  |
| `typescript.md`    | 타입 안전성, 네이밍과 동사 선택, 클래스 구조, enum 대신 as const |

frontmatter의 `paths` glob으로 적용 대상을 지정한다. `code-style.md`와 `comments.md`, `testing.md`, `typescript.md`가 `paths`를 갖는다. 나머지 셋은 파일 경로와 무관한 규칙이라 `paths`가 없다.

`paths`는 경로 매칭으로 룰을 주입하는 프로젝트 훅이 읽는다. 사용자 설정에 링크된 룰은 `paths`와 무관하게 모든 세션에 로드된다.

### .skill-lock.json

스킬별 GitHub 출처, 경로, 폴더 해시, 설치와 갱신 시각을 기록한다. `npx skills check`가 이 해시로 업데이트 여부를 판단한다. 직접 만든 스킬은 여기에 없다.

## 사용법

### 1. 저장소 클론

```bash
git clone https://github.com/chan9yu/docagents.git ~/.agents
```

### 2. 에이전트 디렉토리에 링크

```bash
bash ~/.agents/scripts/link-agents.sh --dry-run   # 무엇이 바뀔지 먼저 본다
bash ~/.agents/scripts/link-agents.sh
```

스킬은 디렉토리 단위로, 룰은 파일 단위로 링크한다. 여러 번 실행해도 안전하고, 이곳에서 사라진 항목의 링크는 지운다. 스킬이나 룰을 추가한 뒤에도 다시 실행한다.

대상은 `~/.claude`이고 `CLAUDE_CONFIG_DIR`을 설정했으면 그쪽을 따른다. 두 디렉토리가 같은 부모 아래 있으면 상대 경로로 링크해 홈 경로가 달라져도 살아남는다.

### 3. 스킬 관리

```bash
npx skills find <query>          # 검색
npx skills add <owner/repo> -g   # 전역 설치
npx skills check                 # 업데이트 확인. 갱신까지 함께 수행한다
npx skills update                # 전체 갱신
```

`check`는 확인만 하지 않고 업데이트까지 진행한다. 설치 후 `skills/`와 `.skill-lock.json` 변경분을 커밋한다.

`playwright-skill`은 의존성을 따로 설치해야 한다. 스킬을 갱신하면 `node_modules`가 사라지므로 다시 돌린다.

```bash
cd ~/.agents/skills/playwright-skill && npm run setup
```

## 요구 사항

- Node.js (`npx skills` 실행용)
- 심볼릭 링크를 지원하는 파일 시스템
