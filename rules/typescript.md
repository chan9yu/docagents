---
description: TypeScript 작성 규칙. 타입 안전성, 네이밍, 클래스 구조
paths: ['**/*.ts', '**/*.tsx', '**/*.mts']
---

# TypeScript 규칙

## 설정

- strict mode 전체 활성화
- ESM을 기본 모듈 시스템으로 쓴다. 상대 import에 확장자를 붙이지 않는다. `.ts`를 붙이면 타입 검사가 거부한다(`allowImportingTsExtensions` 미사용)
- path alias는 저장소가 정한 것을 따른다. 정한 것이 없으면 상대 경로와 패키지명만 쓴다

## import

타입으로만 쓰는 대상은 `import type`으로 명시한다. enum과 클래스처럼 런타임 값으로도 쓰이는 대상은 일반 `import`를 쓴다.

```typescript
// 틀림. enum을 import type으로 가져오면 런타임에 사라진다
import type { ConnectionState } from './types';

// 올바름
import { ConnectionState } from './types';
import type { ClientOptions } from './types';
```

## 타입 안전성

- `any` 금지 (ESLint `no-explicit-any` error). 타입을 알 수 없는 경계에서는 `unknown`과 타입 가드로 좁힌다
- `!` non-null assertion 금지 (ESLint `no-non-null-assertion` error). 타입 가드로 좁힌다. 값이 없을 수 있다는 것이 계약이면 optional chaining을 쓰되 `?? ''` 같은 기본값으로 덮지 않는다
- `as` 단언은 최소화한다. discriminated union과 타입 가드를 먼저 고려한다. 런타임 검증 직후처럼 값을 이미 확인한 자리에서만 허용한다
- 미사용 변수는 `_` prefix로만 허용한다

### 반환 타입

추론되는 반환 타입은 명시하지 않는다. ESLint의 `explicit-function-return-type`이 off이면 반대 방향을 잡는 룰이 없으니 쓰는 쪽에서 지킨다.

예외는 둘이다. 둘 다 반환 타입이 추론의 중복이 아니라 선언인 자리다.

**넓은 입력을 좁히는 함수.** `validateConfig(config: unknown): ClientConfig`가 그렇다. 반환 타입은 추론 결과를 옮긴 것이 아니다. 무엇으로 좁혔는지를 선언한다.

**반환식에서 자기 자신을 참조하는 함수.** 워크스페이스 안에서는 지워도 추론이 동작하고 타입 검사도 살아 있지만, 선언 파일을 방출할 때 그 자리가 `any`로 떨어진다.

```typescript
// : Logger를 지우고 --declaration으로 뽑으면 이렇게 나온다
withTag(tag: string): /*elided*/ any;
```

명시해 두면 호버와 IDE 표시에 타입 이름이 남고, 나중에 타입 배포를 켤 때 조용히 `any`로 회귀하지도 않는다.

## 네이밍

### 파일

저장소 룰에 파일 이름 규칙이 있으면 그것을 따른다. 없을 때의 기본은 이렇다. 역할 접미사가 붙는 도메인 파일은 `{feature}.{role}.ts` 형태로 점 구분한다: `interview.session.ts`, `transport.adapter.ts`, `recording.engine.ts`. 단일 관심사면 단순 이름을 쓴다: `client.ts`, `validation.ts`, `constants.ts`. 이름이 두 단어를 넘으면 하이픈으로 잇는다: `peer-link.ts`, `data-channel.ts`. 대문자와 밑줄은 파일명에 쓰지 않는다.

### 식별자

| 대상             | 규칙                        |
| ---------------- | --------------------------- |
| 클래스           | PascalCase + 역할 접미사    |
| 메서드, 프로퍼티 | camelCase                   |
| 상수             | UPPER_SNAKE_CASE            |
| 인터페이스       | PascalCase, `I` 접두사 금지 |
| 타입 별칭        | PascalCase                  |

인터페이스와 구현체는 다른 이름으로 구분한다(`AuthProvider` 인터페이스, `HmacSha1AuthProvider` 구현). Hungarian notation은 TypeScript 관례가 아니다.

약어는 일반 단어처럼 표기한다: `Http`, `Id`. `HTTP`, `ID`로 쓰지 않는다. 제품 접두어와 에러 클래스에 사내 공통 규칙이 있으면 그쪽을 따른다.

### 동사는 흔한 말로 고른다

격식체 영어 동사를 쓰지 않는다. JavaScript 코드를 읽는 사람이 매일 보는 동사가 따로 있고, 그 밖의 말은 읽는 속도를 늦춘다.

| 쓰지 않는 동사              | 대신 쓰는 동사       |
| --------------------------- | -------------------- |
| acquire, obtain, retrieve   | get, fetch, load     |
| release, dispose, terminate | stop, close, clear   |
| invoke, execute, perform    | run, call, handle    |
| instantiate, materialize    | create, build, make  |
| initialize                  | init, setup, prepare |
| utilize, leverage           | use                  |
| populate, traverse          | fill, walk           |

감싸는 대상이 브라우저 API면 그 API의 동사를 따른다. `getUserMedia`를 감싸는 함수는 `getLocalStream`이지 `acquireLocalMedia`가 아니다. 이름이 원본에서 멀어지면 소비자가 무엇을 감싼 것인지 한 번 더 짚어야 한다.

동사만 있고 목적어가 없는 이름도 쓰지 않는다. `bind`와 `remember`, `dispatch`는 무엇을 하는지 말하지 않는다. `bindClientEvents`, `rememberSubscription`, `dispatchToHandlers`로 적는다. 반대로 동사가 없는 이름도 쓰지 않는다. 형용사로 시작하면 boolean을 돌려주는 술어로 읽힌다.

### 접두사는 역할이 정한다

| 무엇                    | 접두사                       | 예                                           |
| ----------------------- | ---------------------------- | -------------------------------------------- |
| boolean 변수와 속성     | `is`, `has`, `can`, `should` | `isRetrying`, `hasResultType`, `canRefresh`  |
| boolean 상태의 세터     | `set` 뒤에 상태 이름 그대로  | `setIsRetrying`                              |
| 서버에서 받는 함수      | `get`, `fetch`               | `fetchPopups`                                |
| 만드는 함수             | `create`, `build`, `make`    | `createOAuthState`, `buildLoginPath`         |
| 모양을 바꾸는 함수      | `to`, `format`               | `toHref`, `formatClusterText`                |
| 넓은 입력을 좁히는 함수 | `parse`, `sanitize`          | `parseStep`, `sanitizeNextPath`              |
| 검증해 던지는 함수      | `verify`                     | `verifyOAuthState`                           |

접두사를 따르지 않는 자리가 셋 있다. DOM과 ARIA 표준 속성을 그대로 받는 이름(`disabled`, `checked`, `open`), 라이브러리가 이름을 정한 옵션 키(TanStack Query의 `retry`), 외부 SDK의 타입 선언이다. 이 셋은 원본의 이름을 따른다.

boolean이 아닌 값에 형용사만 붙이지 않는다. 배열을 `visible`이라 부르면 참거짓으로 읽힌다. `visiblePopups`로 적는다.

### 클래스 접미사

| 접미사     | 용도                       |
| ---------- | -------------------------- |
| `Adapter`  | 외부 서비스 격리           |
| `Client`   | 외부 시스템 호출 주체      |
| `Session`  | 수명이 있는 상태 보유 객체 |
| `Bus`      | 메시지 라우팅              |
| `Engine`   | 복잡한 워크플로 실행 주체  |
| `Policy`   | 규칙과 전략                |
| `Provider` | 토큰과 리소스 공급         |
| `Resolver` | 조회와 매핑                |
| `Pipeline` | 처리 체인                  |

이벤트 발행에는 별도 접미사를 두지 않는다. 이벤트 전달만 하는 얇은 래퍼를 만들지 말고 도메인 클래스가 이미터를 직접 상속한다.

## 클래스 구조

멤버 순서는 ESLint `member-ordering`으로 강제한다: static 필드, static 메서드, instance 필드, constructor, instance 메서드. 각 그룹 안에서 public, protected, private 순이다.

접근 제어자를 명시하는 규칙(`explicit-member-accessibility`)을 켰다면 constructor 파라미터 프로퍼티에도 붙인다. constructor와 accessor에서는 `public`을 적으면 오히려 오류다. 생략해도 되는 것이 아니라 `public`만 지우고 `private`와 `protected`는 그대로 적는다.

```typescript
export class Client {
	private readonly config: ClientConfig;
	private readonly logger: Logger;

	constructor(config: ClientConfig) { ... }

	public async connect(params: ConnectParams): Promise<Session> { ... }
}
```

내부 상태에는 `private` 키워드를 쓴다. ECMAScript private field(`#`)는 쓰지 않는다. `#`에는 접근 제어자를 붙일 수 없어(TS18010) 명시 규칙과 공존하지 못한다. `private`는 컴파일 타임 보호라 번들에서는 일반 속성이 된다. 런타임 은닉이 실제 요구사항이면 그때 `#`를 검토한다.

`_` prefix는 쓰지 않는다. getter와 이름이 겹치는 백킹 필드는 `currentState`처럼 의미가 드러나는 다른 이름을 준다. 예외는 미사용 변수와 파라미터다(`_roomId: string`).

## enum

enum 대신 `as const` 객체와 유니온 타입을 쓴다.

```typescript
export const CATEGORY = { Member: 0, Connection: 8, Interview: 620 } as const;
export type Category = (typeof CATEGORY)[keyof typeof CATEGORY];
```

번들 크기와 tree-shaking에 유리하고 `import type`으로 잘못 가져와 런타임에 사라지는 사고가 없다.
