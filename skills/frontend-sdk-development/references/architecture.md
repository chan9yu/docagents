# 내부 아키텍처: 변경의 원인으로 경계 긋기

## 실패 패턴: 고객 분기 지옥

SDK를 여러 고객사가 쓰기 시작하면 반드시 커스텀 요구가 온다.
"우리만 추가 검증을 해달라", "우리는 이 옵션을 고정해달라", "우리만 프로모션 정보를 바꿔달라".
가장 쉬운 대응은 분기 추가다:

```ts
async function requestCheckout(params) {
	if (isClientA(clientKey)) {
		// A사를 위한 파라미터 검증 추가
		const isValid = await validateParamsForClientA(params);
		if (!isValid) throw new Error('유효하지 않은 파라미터입니다.');
	}
	if (isClientB(clientKey)) {
		// B사는 할부 개월수 고정
		params.installmentMonths = 1;
	}
	// ...핵심 로직이 끝없는 분기에 파묻힌다
}
```

고객이 늘수록 이 방식은 기하급수적으로 나빠진다:

- 핵심 비즈니스 로직의 가독성이 붕괴된다.
- "이 분기는 누구를 위해, 왜 존재하는가"의 추적 비용이 계속 증가한다.
- 한 고객을 위한 수정이 다른 모든 고객의 코드 경로를 지나간다. 회귀 위험이 전 고객에 퍼진다.

## 원칙: 변경의 원인에 따라 경계를 그어라

계층 분리는 그 자체가 목적이 아니다. 던져야 할 질문은
**"이 코드는 무엇이 바뀔 때 함께 바뀌는가"**다. 변경의 원인이 다른 코드가 한 곳에 있으면
한 가지 변경이 무관한 코드로 파급된다. SDK는 변경 원인이 뚜렷하게 셋으로 나뉜다.

| 계층                 | 변경의 원인                                | 역할                                                    |
| -------------------- | ------------------------------------------ | ------------------------------------------------------- |
| **Public Interface** | 사용자와 약속한 인터페이스가 바뀔 때       | 계약 검증, 공개 모델과 도메인 모델 사이의 번역과 역번역 |
| **Domain**           | 비즈니스 정책과 유스케이스가 바뀔 때       | 핵심 로직. 외부 의존은 인터페이스로만                   |
| **External Service** | 기술 구현(서버 API, 스토리지 등)이 바뀔 때 | 포트의 구현체(어댑터)                                   |

> 이하 예시는 결제 SDK 하나로 통일했지만, 계층을 나누는 기준은 도메인과 무관하다.
> 지도 SDK라면 TileSource가, 채팅 SDK라면 MessageTransport가, 분석 SDK라면
> EventStore가 같은 자리(포트)에 놓인다.

### 1. Public Interface 계층: 계약 검증과 번역

```ts
interface SdkPublicInterface {
	requestCheckout(params: CheckoutParams): Promise<CheckoutResult>;
}

class Sdk implements SdkPublicInterface {
	async requestCheckout(request: CheckoutParams) {
		// 1. 사용자와 약속한 계약을 검증한다
		if (request.failUrl != null && request.successUrl == null) {
			throw new Error('successUrl이 누락되었습니다.');
		}

		// 2. 공개 모델을 도메인 모델로 번역해 유스케이스에 위임한다
		const amount = new Amount(request.amount);
		const result = await this.deps.checkoutUsecase.execute({ ...request, amount });

		// 3. 도메인 응답을 공개 인터페이스 형태로 역번역해 돌려준다
		return { ...result, amount: result.amount.value };
	}
}
```

이 계층 덕분에 도메인 모델을 자유롭게 다듬어도 공개 계약은 흔들리지 않고, 반대로
공개 계약에 필드가 추가돼도 도메인이 오염되지 않는다.

### 2. Domain 계층: 정책과 유스케이스

```ts
interface CheckoutUsecase {
	execute(request: CheckoutRequest): Promise<CheckoutResult>;
}

class StandardCheckoutUsecase implements CheckoutUsecase {
	constructor(
		private readonly gateway: PaymentGateway, // 인터페이스(포트)에만 의존
		private readonly customerRepo: CustomerRepository // 구현체를 모른다
	) {}

	async execute(request: CheckoutRequest): Promise<CheckoutResult> {
		// 비즈니스 정책 검증
		if (!request.agreement.isRequiredTermsAgreed()) {
			throw new NeedAgreementWithRequiredTermsError();
		}
		await request.method.validate();

		// 외부 의존성은 인터페이스를 통해 요청
		const merchantId = await this.gateway.getMerchantId(request.method);
		const customer = this.customerRepo.getCustomer();

		// ...핵심 비즈니스 로직
	}
}
```

### 3. External Service 계층: 포트와 어댑터

```ts
// 포트: 도메인이 필요로 하는 능력의 선언
interface PaymentGateway {
	getMerchantId(method: PaymentMethod): Promise<MerchantId>;
}
interface CustomerRepository {
	getCustomer(): Customer;
}

// 어댑터: 기술 구현
class HttpPaymentGateway implements PaymentGateway {
	async getMerchantId(method: PaymentMethod) {
		return this.httpClient.get(/* ... */); // HTTP 기반 구현
	}
}
class SessionCustomerRepository implements CustomerRepository {
	getCustomer() {
		return this.sessionStorage.get('@sdk/customer');
	}
}
```

HTTP를 다른 전송 방식으로 바꾸든, sessionStorage를 다른 저장소로 바꾸든
도메인 계층은 한 줄도 바뀌지 않는다.

## 의존성 역전과 런타임 조립

핵심 장치는 **의존성 역전**이다. 도메인이 구현체를 import하는 순간 계층 경계는 장식이 된다.

- 도메인 계층은 인터페이스(포트)에만 의존한다. 의존성 화살표는 항상 도메인을 향한다.
- 어떤 구현체를 쓸지는 조립 지점(composition root)에서 런타임에 결정한다.

```ts
function createSdk(clientKey: string): Sdk {
	const gateway = new HttpPaymentGateway(httpClient);
	const customerRepo = new SessionCustomerRepository(sessionStorage);
	const checkoutUsecase = new StandardCheckoutUsecase(gateway, customerRepo);
	return new Sdk({ checkoutUsecase });
}
```

이렇게 하면 각 계층은 느슨하게 결합되고, 계층 내부는 높은 응집도를 유지한다.
테스트에서도 포트에 목(mock)을 꽂기만 하면 도메인 로직을 단독으로 검증할 수 있다.

## 고객 커스텀은 블록 교체다

이 구조의 진짜 보상은 커스텀 요구가 왔을 때 나타난다. SDK를 레고 블록처럼
독립 기능 단위로 조립해 두었기 때문에, 특정 고객의 요구는 **해당 블록 하나를 교체**하는
것으로 끝난다.

A사가 "우리만 결제 전 추가 검증을 해달라"고 요구하면:

```ts
class ClientACheckoutUsecase implements CheckoutUsecase {
	constructor(
		private readonly standard: StandardCheckoutUsecase, // 표준 로직 재사용
		private readonly gateway: PaymentGateway
	) {}

	async execute(request: CheckoutRequest): Promise<CheckoutResult> {
		// A사 전용 검증만 추가하고
		await this.gateway.validateRequestParams(request);
		// 나머지는 표준에 위임한다
		return this.standard.execute(request);
	}
}

// 다른 점은 조립 시점뿐이다
const checkoutUsecase =
	clientKey === CLIENT_A_KEY ? new ClientACheckoutUsecase(standardUsecase, gateway) : standardUsecase;
```

고객 식별 분기가 허용되는 유일한 장소가 바로 이 조립 지점(composition root)이다.
금지하는 것은 표준 로직과 도메인 로직 **내부**의 분기다. 조립 지점의 분기는 한 곳에 모여 있어
전체 커스텀 현황이 한눈에 드러나고 추적할 수 있다.

- 표준 유스케이스 코드는 한 줄도 바뀌지 않는다. 코드 오염이 없다.
- 커스텀 요구가 누구를 위한 것인지 파일(클래스) 단위로 드러난다. 추적이 공짜다.
- A사 커스텀의 버그는 A사 경로에만 존재한다. 회귀 범위가 격리된다.

분기(`if`)와 교체(구현체 주입)의 차이는 사소해 보이지만, 고객이 10곳, 100곳이 될 때
유지보수 비용의 차이는 기하급수적으로 벌어진다.

## 체크리스트

- [ ] 인터페이스 변경과 정책 변경, 기술 교체가 각각 정확히 한 계층만 건드리는가
- [ ] 도메인 계층에 구현체(HTTP 클라이언트, 스토리지, 플랫폼 API) import가 없는가
- [ ] 표준 로직 안에 특정 고객을 식별하는 분기가 없는가
- [ ] 커스텀 요구를 블록(유스케이스와 어댑터) 교체만으로 수용할 수 있는가
- [ ] 조립 지점(composition root)이 한 곳으로 모여 있는가
- [ ] 포트에 목을 꽂는 것만으로 도메인 로직을 단독 테스트할 수 있는가
