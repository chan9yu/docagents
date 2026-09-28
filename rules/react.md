---
description: React 컴포넌트 규칙. props 는 interface 로 선언하고 이벤트 핸들러는 handle, 이벤트 props 는 on, 훅은 use 로 짓는다
paths: ['**/*.tsx', '**/*.jsx']
---

# React 규칙

## 이름

| 무엇                                   | 접두사                      | 예                                                        |
| -------------------------------------- | --------------------------- | --------------------------------------------------------- |
| 컴포넌트 안에서 이벤트를 처리하는 함수 | `handle` 뒤에 이벤트나 대상 | `handleLogout`, `handleViewChange`, `handleListItemClick` |
| 이벤트를 받는 props                    | `on` 뒤에 이벤트            | `onChange`, `onLocate`, `onSwitchToList`                  |
| 훅                                     | `use`                       | `useCurrentPosition`                                      |

이벤트 핸들러의 `handle`과 이벤트 props의 `on`은 React 공식 문서(react.dev의 Responding to Events)가 적은 관례다. boolean 상태의 `is`와 세터 이름은 `typescript.md`의 접두사 표에 있다.

`on` props에 넘기는 함수는 `handle`로 시작한다. 훅이나 props로 받은 함수를 그대로 넘기는 것이면 원래 이름을 둔다.

## props 선언

**컴포넌트 props는 `interface`로 선언한다.** HTML 속성이나 variant 타입을 더할 때는 `&` 대신 `extends`로 잇는다.

```tsx
interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof buttonVariants> {}
```

TypeScript 핸드북은 `type`의 기능이 필요할 때까지 `interface`를 쓰라고 하고, TypeScript 성능 위키는 `A & B` 대신 `interface extends`를 권한다. `interface`는 속성 충돌을 오류로 드러내고 타입 관계가 캐시된다.

**합집합이 필요하면 경우마다 `interface`를 적고 합집합만 `type`으로 잇는다.** `interface`는 합집합을 표현하지 못한다.

```tsx
interface KakaoMapFitProps extends KakaoMapCommonProps {
	fitTo: readonly KakaoLatLngLiteral[];
	center?: never;
}
interface KakaoMapCenterProps extends KakaoMapCommonProps {
	fitTo?: never;
	center: KakaoLatLngLiteral;
}
export type KakaoMapProps = KakaoMapFitProps | KakaoMapCenterProps;
```

JSX를 돌려주는 return 앞 빈 줄은 `code-style.md`의 return과 빈 줄 절에 있다.
