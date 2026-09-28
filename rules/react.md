---
description: React 컴포넌트 이름 규칙. 이벤트 핸들러는 handle, 이벤트 props 는 on, 훅은 use 로 짓는다
paths: ['**/*.tsx', '**/*.jsx']
---

# React 규칙

## 이름

| 무엇                                   | 접두사                      | 예                                                        |
| -------------------------------------- | --------------------------- | --------------------------------------------------------- |
| 컴포넌트 안에서 이벤트를 처리하는 함수 | `handle` 뒤에 이벤트나 대상 | `handleLogout`, `handleViewChange`, `handleListItemClick` |
| 이벤트를 받는 props                    | `on` 뒤에 이벤트            | `onChange`, `onLocate`, `onSwitchToList`                  |
| 훅                                     | `use`                       | `useCurrentPosition`                                      |

이벤트 핸들러의 `handle`과 이벤트 props의 `on`은 React 공식 문서(react.dev의 Responding to Events)가 적은 관례다. boolean 상태의 `is`와 세터 이름은 `~/.agents/rules/typescript.md`의 접두사 표에 있다.

`on` props에 넘기는 함수는 `handle`로 시작한다. 훅이나 props로 받은 함수를 그대로 넘기는 것이면 원래 이름을 둔다.
