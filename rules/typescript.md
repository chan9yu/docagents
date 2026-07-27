---
description: TypeScript 코드 작성 시 규칙
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript 규칙

## TypeScript 설정

- **Strict Mode**: 전체 활성화
- **Path Aliases**: 사용하지 않음 (상대 경로 사용)
- **ESM**: 기본 모듈 시스템

## Import 규칙

- 타입으로만 사용하는 대상은 `import type`으로 명시한다.
- enum·클래스처럼 런타임 값으로도 쓰이는 대상은 일반 `import`를 사용한다.

```typescript
// 틀림 — enum을 import type으로 가져오면 런타임 에러!
import type { ConnectionState } from './types';

// 올바름 — enum은 런타임 값
import { ConnectionState } from './types';

// 올바름 — 타입 전용 대상은 import type
import type { ClientOptions } from './types';
```

## 타입 안전성

- `any` 타입 금지 (ESLint `no-explicit-any` error로 강제). 타입을 알 수 없는 경계에서는 `unknown` + type guard로 좁힌다.
- `as` 타입 단언 지양 — discriminated union, type guard 활용
- `!` non-null assertion 금지 (ESLint `no-non-null-assertion` error로 강제) — `?.` optional chaining·type guard 활용
- 자동 추론 가능한 리턴 타입은 명시하지 않는다.

## 네이밍 컨벤션

### 파일

- `{feature}.{role}.ts` — 점으로 feature와 role 구분
- 예: `transport.adapter.ts`, `hmac-sha1.auth-provider.ts`, `recording.engine.ts`

### 클래스/변수

- 클래스: `PascalCase` + 역할 접미사 (Manager, Adapter, Config 등)
- 메서드/프로퍼티: `camelCase`
- 상수: `UPPER_SNAKE_CASE`
- 인터페이스: `PascalCase`, **I 접두사 금지** — 도메인 이름만 사용 (`AuthProvider`, `MediaProcessor`). Java/C# 스타일의 Hungarian notation은 TypeScript 커뮤니티 관례에 맞지 않는다. 인터페이스와 구현체는 역할이 드러나는 이름으로 구분한다 (예: `AuthProvider` 인터페이스 / `HmacSha1AuthProvider` 구현체)

### 클래스 역할 접미사

| 접미사     | 용도                        | 예시                                              |
| ---------- | --------------------------- | ------------------------------------------------- |
| `Adapter`  | 외부 인터페이스 구현체      | `TransportAdapter`                                |
| `Resolver` | 조회·매핑                   | `PermissionResolver`                              |
| `Provider` | 토큰·리소스 공급            | `HmacSha1AuthProvider`, `StaticTokenAuthProvider` |
| `Engine`   | 실행 주체 (복잡한 워크플로) | `RecordingEngine`                                 |
| `Bridge`   | 외부 시스템 연결            | `AnalyzerBridge`                                  |
| `Policy`   | 규칙·전략                   | `ReconnectPolicy`                                 |
| `Pipeline` | 처리 체인                   | `MediaPipeline`                                   |

이벤트 시스템은 별도 접미사를 두지 않는다. 이벤트 전달만 하는 얇은 래퍼(투명 프록시)를 만들지 말고, 도메인 클래스가 `EventEmitter<XxxEventListenerMap>`을 직접 상속한다.

## Private 필드 네이밍

`private` 필드에 `_` prefix를 붙이지 않는다. TypeScript의 `private` 키워드 자체로 접근 제어가 충분하다.

```typescript
// 틀림
private _token: string | null = null;
private readonly _authProvider: AuthProvider;

// 올바름
private token: string | null = null;
private readonly authProvider: AuthProvider;
```

**예외**: ESLint `no-unused-vars` 대응용 미사용 파라미터는 `_param` 패턴 유지 (예: `_roomId: string`).

## 클래스 멤버 순서

1. Static 프로퍼티 (public → private)
2. Instance 프로퍼티 (public → private)
3. Constructor
4. Getter / Setter
5. Public 메서드
6. Private 메서드
