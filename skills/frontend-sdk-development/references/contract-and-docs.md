# 계약으로서의 인터페이스: 명세와 변경 관리, 문서, 검증

## 관점 전환: 함수가 아니라 계약

SDK의 공개 인터페이스는 "내가 만들어 남에게 주는 함수"가 아니라 **사용자와 맺는 계약**이다.
이 관점 전환이 중요한 이유: 함수는 만든 사람이 마음대로 고칠 수 있지만 계약은 그럴 수 없다.
계약은 다음을 요구한다.

- 타입으로 표현하는 형식, 문서로 적는 의미와 제약, 에러로 드러나는 실패 조건이 **모두** 명시되어야 한다.
- 일방적으로 변경할 수 없다. 변경에는 절차와 기록이 필요하다.
- 언제, 왜, 어떤 의도로 바뀌었는지 추적할 수 있어야 한다.

연동 개발자가 파라미터의 제약과 의미를 스스로 학습하게 두면, 그 비용은 부정확한 연동과
높은 커뮤니케이션 비용(문의, 디버깅 지원)으로 SDK 팀에 되돌아온다.

## 1. 계약의 명시화: 타입과 JSDoc

계약의 1차 표현은 TypeScript 인터페이스와 JSDoc이다.
필드마다 의미와 제약, 예시를, 함수마다 반환값과 발생 가능한 에러를 전부 기술한다.

```ts
export interface MapOptions {
	/**
	 * 지도를 렌더링할 컨테이너입니다. CSS 선택자 문자열 또는 HTMLElement를
	 * 받으며, 선택자가 가리키는 요소가 문서에 존재해야 합니다.
	 */
	container: string | HTMLElement;

	/**
	 * 초기 중심 좌표입니다. 위도(lat)는 -90 이상 90 이하,
	 * 경도(lng)는 -180 이상 180 이하의 숫자여야 합니다.
	 */
	center: { lat: number; lng: number };

	/**
	 * 초기 줌 레벨입니다. 1(세계)부터 20(건물)까지의 정수이며,
	 * 생략하면 10이 적용됩니다.
	 */
	zoom?: number;
}

/**
 * 지도를 생성해 컨테이너에 마운트합니다.
 * @param options - 지도 생성 옵션입니다.
 * @returns 지도 핸들(`MapHandle`)이 반환됩니다. `handle.destroy()`로 정리합니다.
 *
 * @throws {ContainerNotFoundError} container가 가리키는 요소가 문서에 없는 경우
 * @throws {InvalidApiKeyError} API 키가 유효하지 않거나 만료된 경우
 */
export type CreateMap = (options: MapOptions) => Promise<MapHandle>;
```

합격 기준은 하나다: **문서 사이트 없이 타입 정의만 보고 연동 코드를 쓸 수 있는가.**
에러까지 명세하는 이유: 실패 처리는 연동 코드의 절반이다. 어떤 에러가 언제 나오는지
계약에 없으면 사용자는 프로덕션에서 처음 만난다.

## 2. 계약의 패키지 분리

계약을 구현체와 같은 코드베이스에 섞어 두지 말고, 별도 패키지로 분리하라.

```ts
// 계약 패키지: @your-org/analytics-contract
export interface AnalyticsPublicInterface {
	track(event: TrackEvent): void;
}

// 구현 패키지에서 계약을 구현
import { AnalyticsPublicInterface } from '@your-org/analytics-contract';

class AnalyticsSdk implements AnalyticsPublicInterface {
	track(event: TrackEvent): void {
		// ...
	}
}
```

물리적 분리가 주는 것:

- **계약 변경이 명시적 사건이 된다.** 구현을 아무리 고쳐도 계약 패키지 버전은 그대로다.
  계약 패키지에 변경이 생겼다면 사용자와의 약속이 바뀌었다는 신호다.
- **변경 시점이 분리된다.** 내부 리팩토링과 계약 변경이 다른 릴리스 주기를 가질 수 있다.

## 3. Git을 계약서로: 커밋 컨벤션

계약 변경 커밋에는 세 가지를 강제하라.

```text
(변경 내용) [제품/모듈]의 [API|파라미터|응답] [이름]을 [추가|변경|삭제]

(변경 이유) XX 고객사의 YY 유즈케이스를 지원하기 위해 (요구사항 출처 링크)

(설계 의도) 기존 요소로 해결하지 않은 이유, 검토한 대안, 결정 근거
```

예시:

```text
AuthorizeOptions 모델에 'redirectUri' 파라미터 추가

(변경 이유) 팝업 차단 환경에서 인증이 불가능하다는 연동사 문의 다수 (문의 티켓 링크)
(설계 의도) 팝업 방식을 리다이렉트 방식으로 대체하는 안은 기존 연동사 전체에
breaking change라 기각. 기존 팝업 방식은 유지하고 리다이렉트를 optional 선택지로
추가 (인증 플로우 설계 리뷰 문서 참고)
```

이렇게 하면 Git이 계약서이자 히스토리북이 된다. 계약 변경의 의도와 배경, 시점을
`git log` 한 곳에서 추적할 수 있고, 슬랙과 위키에 흩어져 소멸하던 의사결정 기록 문제가 사라진다.
"이 파라미터는 왜 있지?"라는 질문의 답이 항상 코드 옆에 있다.

## 4. 살아있는 문서: 계약에서 자동 생성

손으로 관리하는 연동 문서는 반드시 낡는다. 코드는 리뷰를 거치지만 문서 수정은 잊히기
때문이다. 부정확한 문서는 없는 문서보다 나쁘다. 사용자가 문서를 의심하기 시작하면
모든 것을 문의로 해결하려 든다.

해법은 문서를 계약 코드에서 자동 생성하는 것이다.

1. 계약(타입+JSDoc)을 변경한다.
2. 계약 패키지를 릴리스한다.
3. 릴리스 CI가 문서 생성 워크플로를 자동 트리거한다.
4. 타입 정의를 파싱해(TypeScript 컴파일러 API 등) 문서 페이지를 생성한다.
5. 문서 사이트에 배포한다.

```yaml
# release.yml: 릴리스 후 문서 갱신 트리거 (개념 스케치)
- name: Trigger SDK docs generation
  if: steps.release.outputs.published == 'true'
  run: gh workflow run docs-update.yml --repo your-org/docs --ref main
```

효과: 코드와 문서가 구조적으로 동기화된다. 문서 관리라는 업무 자체가 사라진다.

## 5. 런타임 검증 계층

타입은 컴파일 타임에만 존재한다. 외부 호출자는 내 타입 정의의 지배를 받지 않으므로,
계약을 실제로 강제하는 것은 진입점의 런타임 검증이다.

계약 타입과 1:1로 대응하는 스키마를 정의하고(zod 등 스키마 라이브러리를 쓰거나
타입에서 스키마를 자동 생성), 공개 메서드 진입점에서 일괄 적용한다:

```ts
// 1절의 MapOptions 계약과 1:1로 대응하는 스키마
const MapOptionsSchema = z.object({
	container: z.union([z.string(), z.instanceof(HTMLElement)]),
	center: z.object({
		lat: z.number().min(-90).max(90),
		lng: z.number().min(-180).max(180)
	}),
	zoom: z.number().int().min(1).max(20).optional()
});

export function ValidateParameters(criterion: Schema, ErrorCtor: new (message: string) => Error) {
	return function (_target: any, _key: string, descriptor: PropertyDescriptor) {
		const original = descriptor.value;
		descriptor.value = function (...args: any[]) {
			const result = criterion.safeParse(args[0]);
			if (!result.success) {
				throw new ErrorCtor(translateSchemaError(result.error));
			}
			return original.apply(this, args);
		};
		return descriptor;
	};
}
```

핵심은 검증 실패를 **사용자의 언어로 번역**하는 것이다. 스키마 라이브러리의 원시 에러를
그대로 던지지 마라. "어떤 파라미터가, 왜 잘못됐는지"를 그대로 말해야 한다:

```ts
function translateSchemaError(error: SchemaError): string {
	const names = wrongParameterNames(error).join(', ');
	switch (primaryIssueCode(error)) {
		case 'invalid_type':
			return `${names} 파라미터의 타입이 올바르지 않습니다.`;
		case 'missing_required':
			return `${names} 필수 파라미터가 누락되었습니다.`;
		case 'unrecognized_keys':
			return `${names}는 정의되지 않은 파라미터입니다.`;
		case 'out_of_range':
			return `${names} 파라미터의 값이 허용 범위를 벗어났습니다.`;
		// ...
	}
}
```

효과:

- 연동 실수(타입 오류, 필수값 누락)가 프로덕션이 아니라 개발 단계의 첫 호출에서
  즉시 적발된다.
- 잘못된 데이터가 도메인 계층까지 흘러가지 않는다.
- 명확한 에러 메시지가 문의를 대체한다. 커뮤니케이션 비용이 코드로 흡수된다.

## 체크리스트

- [ ] 공개 타입의 모든 필드에 의미와 제약, 예시가 JSDoc으로 있는가
- [ ] 모든 공개 함수에 반환값과 발생 가능한 에러가 명세되어 있는가
- [ ] 타입 정의만 보고 연동 코드를 쓸 수 있는가 (문서 없이)
- [ ] 계약이 구현과 분리된 패키지로 관리되는가
- [ ] 계약 변경 커밋에 변경 내용과 이유, 설계 의도가 담기는가
- [ ] 연동 문서가 계약 코드에서 자동 생성되는가
- [ ] 모든 공개 API 진입점에 런타임 스키마 검증이 있는가
- [ ] 검증 에러가 "어떤 필드가 왜"를 사용자의 언어로 말하는가
