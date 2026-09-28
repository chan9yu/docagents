---
description: 코드 스타일과 가독성 규칙
paths: ['**/*.ts', '**/*.tsx', '**/*.mts', '**/*.js', '**/*.jsx', '**/*.mjs']
---

# 코드 스타일

포맷은 포맷터가 강제한다. 손으로 맞추지 말고 프로젝트의 format 명령에 맡긴다. 아래는 포맷터가 잡지 못하는 것이다.

## 근접성

관련 있는 것은 붙이고 다른 관심사는 빈 줄로 가른다.

```typescript
const { userId, roomId, role } = params;

const adapter = this.createAdapter();
```

## return과 빈 줄

return 앞 빈 줄은 문맥으로 판단하지 않고 줄 수로 정한다. 누가 써도 같은 모양이 나온다.

- **return을 담은 블록이 빈 줄을 빼고 3줄 이하면 return 앞에 빈 줄을 두지 않는다.** return 줄도 센다. 3줄을 넘으면 빈 줄을 둔다. return이 블록의 첫 문장이면 두지 않는다
- **JSX를 돌려주는 return 앞에는 블록 길이와 상관없이 빈 줄을 둔다.** 컴포넌트에서 값을 준비하는 부분과 그리는 부분이 갈려 보인다. 첫 문장이면 두지 않는다
- **블록이 닫힌 뒤 다음 문장 앞에는 빈 줄을 둔다.** 이어지는 `if` 둘 사이도 같다. `else`와 `catch`, `finally`처럼 같은 문장이 이어지면 두지 않는다

```tsx
export function buildLoginPath(next: string) {
	const safePath = sanitizeNextPath(next) ?? DEFAULT_NEXT_PATH;
	return `/login?next=${encodeURIComponent(safePath)}`;
}

export default async function LoginPage({ searchParams }: PageProps) {
	const { next } = await searchParams;
	const requestedNext = typeof next === 'string' ? next : null;

	return <LoginScreen next={sanitizeNextPath(requestedNext)} />;
}

function hasErrorMessageShape(error: unknown) {
	if (typeof error !== 'object' || error === null) {
		return false;
	}

	const { errorCode, message } = error as Record<string, unknown>;

	return typeof errorCode === 'string' && typeof message === 'string';
}
```

## 한 줄 블록 금지

`if`와 `for`의 본문은 중괄호로 감싸고 줄을 나눈다. 한 줄에 붙이면 조건과 실행이 한 덩어리로 보여 분기를 놓친다.

```typescript
// 틀림
if (!storageKey) return LEVELS[defaultLevel];

// 올바름
if (!storageKey) {
	return LEVELS[defaultLevel];
}
```

eslint `curly: ['error', 'all']`로 강제할 수 있다.

## return의 객체 리터럴

`return`이 객체 리터럴을 돌려줄 때는 속성마다 줄을 나눈다. 폭이 남아도 접지 않는다.

```typescript
// 틀림
return { host, port, tls: window.location.protocol === 'https:' };

// 올바름
return {
	host,
	port,
	tls: window.location.protocol === 'https:'
};
```

prettier가 객체 리터럴의 개행을 보존하므로 한 번 펼치면 그대로 남는다. 빈 객체를 돌려주는 `return {}`는 예외다.

## 이터러블 매핑

이터러블을 배열로 매핑할 때는 스프레드로 펼친 뒤 map을 부르지 않고 `Array.from`의 매핑 인자를 쓴다. 순회하면서 바로 매핑하므로 중간 배열이 생기지 않는다.

```typescript
// 틀림
const requests = [...grouped].map(toRequest);

// 올바름
const requests = Array.from(grouped, toRequest);
```

## 겹친 객체 리터럴 인자

인자 자리의 객체 안에서 또 객체를 만들지 않는다. 안쪽 객체를 변수로 꺼내면 호출이 한 줄로 남고 넘기기 직전 값을 확인할 지점이 생긴다.

```typescript
// 틀림
this.emit('error', {
	error: new ConnectionError({ code: 'CONNECTION_LOST', message: '...', cause })
});

// 올바름
const error = new ConnectionError({ code: 'CONNECTION_LOST', message: '...', cause });
this.emit('error', { error });
```

한 겹이어도 인자가 폭을 넘어 호출 괄호가 계단으로 터지면 같은 방식으로 꺼낸다. 한 줄에 들어가는 호출은 인라인이 낫다.

## 일관성

같은 종류의 일은 같은 모양으로 쓴다. 한 파일 안에서 어떤 검증은 throw하고 어떤 검증은 boolean을 반환하면 읽는 사람이 매번 확인해야 한다.

## 매직 넘버 제거

```typescript
// 틀림
setTimeout(callback, 180000);

// 올바름
const ABEND_GRACE_MS = 180_000;
setTimeout(callback, ABEND_GRACE_MS);
```

숫자에 이름을 붙이면 그 값의 근거를 물을 수 있다.

## 복잡한 조건 추출

```typescript
// 틀림
if (session.state === 'connected' && this.isOwner && !this.active) { ... }

// 올바름
const canStart = session.state === 'connected' && this.isOwner && !this.active;
if (canStart) { ... }
```

## 단일 책임

한 함수는 한 가지 일만 한다. 함수가 20줄을 넘으면 나눌 자리를 찾는다. 다만 분리 자체가 목적이 되면 안 된다. 이름 붙일 수 없는 조각으로 쪼개면 오히려 읽기 어렵다.

## 로깅

프로젝트에 로거가 있으면 프로덕션 경로에서 `console.*`를 직접 쓰지 않고 로거를 쓴다. 로거 없이 `console`에 접두사를 붙이는 식으로 저장소가 로그 방식을 정했으면 그것을 따른다.

```typescript
// 틀림
console.log('token loaded', token);

// 올바름
logger.debug('token loaded');
logger.warn('reconnect attempt', { attempt, maxAttempts });
```

테스트와 데모는 `console` 허용이다.

## 시간과 식별자 정규화

컨텍스트가 다른 곳(다른 창, 다른 프로세스, 외부 이벤트)에서 온 값을 비교할 때는 명시적으로 정규화한다.

- 창을 넘는 시간 비교에는 `Date.now()`를 쓴다. 저장소가 현재 시각 함수를 따로 감싸 두었으면 그 함수를 쓴다. `performance.now()`는 컨텍스트마다 원점이 달라 음수나 거대한 값이 나온다. 같은 창 안의 고해상도 측정에만 쓴다
- 외부에서 온 식별자는 문자열일 수도 숫자일 수도 있다. 비교 전에 한쪽으로 통일한다
- 같은 필드명에 다른 의미가 오면(응답의 `ok` 문자열과 대상 id 숫자) `typeof`로 명시 분기하거나 가드 함수로 묶는다

## 주석

기본은 주석 0이다. 상세는 `comments.md`가 정한다.
