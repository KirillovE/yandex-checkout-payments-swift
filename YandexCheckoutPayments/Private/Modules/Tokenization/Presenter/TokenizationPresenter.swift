import Foundation
import FunctionalSwift
import PassKit
import YandexCheckoutPaymentsApi
import struct YandexCheckoutWalletApi.AuthTypeState
import enum YandexCheckoutWalletApi.AuthType

class TokenizationPresenter: NSObject { // NSObject needs for PKPaymentAuthorizationViewControllerDelegate

    // MARK: - VIPER module

    var router: TokenizationRouterInput!
    var interactor: TokenizationInteractorInput!
    weak var moduleOutput: TokenizationModuleOutput?
    weak var view: TokenizationViewInput?

    // MARK: - Data

    private let inputData: TokenizationModuleInputData

    init(inputData: TokenizationModuleInputData) {
        self.inputData = inputData
    }

    // MARK: - Modules

    private weak var yamoneyAuthModule: YamoneyAuthModuleInput?
    private weak var paymentMethodsModuleInput: PaymentMethodsModuleInput?

    // MARK: - Module data

    private var paymentOptionsCount: Int = 0
    private var strategy: TokenizationStrategyInput?
    private var tokenizeData: TokenizeData?
    private var isReusableToken: Bool?

    private var paymentOption: PaymentOption? {
        didSet {
            strategy = paymentOption.map {
                makeStrategy(paymentOption: $0,
                             output: self,
                             testModeSettings: inputData.testModeSettings,
                             paymentMethodsModuleInput: paymentMethodsModuleInput,
                             returnUrl: inputData.returnUrl ?? Constants.returnUrl,
                             isLoggingEnabled: inputData.isLoggingEnabled)
            }
        }
    }

    private var shouldChangePaymentOptions: Bool {
        return paymentOptionsCount > Constants.minimalRecommendedPaymentsOptions
    }

    private var paymentMethodViewModel: PaymentMethodViewModel? {
        return makePaymentMethodViewModel <^> paymentOption
    }

    private lazy var termsOfService: TermsOfService = {
        TermsOfServiceFactory.makeTermsOfService()
    }()

    private func makePaymentMethodViewModel(paymentOption: PaymentOption) -> PaymentMethodViewModel {
        let yandexLogin = interactor.getYandexDisplayName()
        return PaymentMethodViewModelFactory.makePaymentMethodViewModel(paymentOption: paymentOption,
                                                                        yandexDisplayName: yandexLogin)
    }
}

// MARK: - Modules presenting

extension TokenizationPresenter: TokenizationStrategyOutput {
    func presentPaymentMethodsModule() {
        let paymentMethodsInputData
            = PaymentMethodsModuleInputData(clientApplicationKey: inputData.clientApplicationKey,
                                            gatewayId: inputData.gatewayId,
                                            amount: inputData.amount,
                                            tokenizationSettings: inputData.tokenizationSettings,
                                            testModeSettings: inputData.testModeSettings,
                                            isLoggingEnabled: inputData.isLoggingEnabled)

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.presentPaymentMethods(inputData: paymentMethodsInputData,
                                                    moduleOutput: strongSelf)
        }
    }

    func presentYamoneyAuthParametersModule(paymentOption: PaymentOption) {
        let viewModel = makePaymentMethodViewModel(paymentOption: paymentOption)
        let tokenizeScheme = TokenizeSchemeFactory.makeTokenizeScheme(paymentOption)

        let yamoneyAuthParametersInputData
            = YamoneyAuthParametersModuleInputData(shopName: inputData.shopName,
                                                   purchaseDescription: inputData.purchaseDescription,
                                                   paymentMethod: viewModel,
                                                   price: makePriceViewModel(paymentOption),
                                                   fee: makeFeePriceViewModel(paymentOption),
                                                   shouldChangePaymentMethod: shouldChangePaymentOptions,
                                                   paymentOption: paymentOption,
                                                   testModeSettings: inputData.testModeSettings,
                                                   tokenizeScheme: tokenizeScheme,
                                                   isLoggingEnabled: inputData.isLoggingEnabled,
                                                   customizationSettings: inputData.customizationSettings,
                                                   termsOfService: termsOfService)
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.presentYamoneyAuthParameters(inputData: yamoneyAuthParametersInputData,
                                                           moduleOutput: strongSelf)
        }
    }

    func presentYamoneyAuthModule(paymentOption: PaymentOption,
                                  processId: String,
                                  authContextId: String,
                                  authTypeState: AuthTypeState) {
        let viewModel = makePaymentMethodViewModel(paymentOption: paymentOption)
        let tokenizeScheme = TokenizeSchemeFactory.makeTokenizeScheme(paymentOption)

        let yamoneyAuthInputData = YamoneyAuthModuleInputData(shopName: inputData.shopName,
                                                              purchaseDescription: inputData.purchaseDescription,
                                                              paymentMethod: viewModel,
                                                              price: makePriceViewModel(paymentOption),
                                                              fee: makeFeePriceViewModel(paymentOption),
                                                              processId: processId,
                                                              authContextId: authContextId,
                                                              authTypeState: authTypeState,
                                                              shouldChangePaymentMethod: shouldChangePaymentOptions,
                                                              testModeSettings: inputData.testModeSettings,
                                                              tokenizeScheme: tokenizeScheme,
                                                              isLoggingEnabled: inputData.isLoggingEnabled,
                                                              termsOfService: termsOfService)
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.presentYamoneyAuth(inputData: yamoneyAuthInputData,
                                                 moduleOutput: strongSelf)
        }
    }

    func presentContract(paymentOption: PaymentOption) {
        let viewModel = makePaymentMethodViewModel(paymentOption: paymentOption)
        let tokenizeScheme = TokenizeSchemeFactory.makeTokenizeScheme(paymentOption)
        let moduleInputData = ContractModuleInputData(shopName: inputData.shopName,
                                                      purchaseDescription: inputData.purchaseDescription,
                                                      paymentMethod: viewModel,
                                                      price: makePriceViewModel(paymentOption),
                                                      fee: makeFeePriceViewModel(paymentOption),
                                                      shouldChangePaymentMethod: shouldChangePaymentOptions,
                                                      testModeSettings: inputData.testModeSettings,
                                                      tokenizeScheme: tokenizeScheme,
                                                      isLoggingEnabled: inputData.isLoggingEnabled,
                                                      termsOfService: termsOfService)

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.presentContract(inputData: moduleInputData,
                                              moduleOutput: strongSelf)
        }
    }

    func presentBankCardDataInput() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let bankCardDataInputData
                = BankCardDataInputModuleInputData(cardScanner: self.inputData.cardScanning,
                                                   testModeSettings: self.inputData.testModeSettings,
                                                   isLoggingEnabled: self.inputData.isLoggingEnabled)
            self.router.presentBankCardDataInput(inputData: bankCardDataInputData,
                                                 moduleOutput: self)
        }
    }

    func presentMaskedBankCardDataInput(paymentOption: PaymentInstrumentYandexMoneyLinkedBankCard) {
        let moduleInputData = MaskedBankCardDataInputModuleInputData(
            cardMask: paymentOption.cardMask,
            testModeSettings: inputData.testModeSettings,
            isLoggingEnabled: inputData.isLoggingEnabled,
            analyticsEvent: .screenLinkedCardForm,
            tokenizeScheme: .linkedCard
        )
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.router.presenMaskedBankCardDataInput(
                inputData: moduleInputData,
                moduleOutput: self
            )
        }
    }

    func presentSberbankContract(paymentOption: PaymentOption) {
        let viewModel = makePaymentMethodViewModel(paymentOption: paymentOption)
        let priceViewModel = makePriceViewModel(paymentOption)
        let tokenizeScheme = TokenizeSchemeFactory.makeTokenizeScheme(paymentOption)

        let moduleInputData = SberbankModuleInputData(shopName: inputData.shopName,
                                                      purchaseDescription: inputData.purchaseDescription,
                                                      paymentMethod: viewModel,
                                                      price: priceViewModel,
                                                      fee: makeFeePriceViewModel(paymentOption),
                                                      shouldChangePaymentMethod: shouldChangePaymentOptions,
                                                      testModeSettings: inputData.testModeSettings,
                                                      tokenizeScheme: tokenizeScheme,
                                                      isLoggingEnabled: inputData.isLoggingEnabled,
                                                      phoneNumber: inputData.userPhoneNumber,
                                                      termsOfService: termsOfService)
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.presentSberbank(inputData: moduleInputData,
                                              moduleOutput: strongSelf)
        }
    }

    func present3dsModule(inputData: CardSecModuleInputData) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.present3dsModule(inputData: inputData,
                                               moduleOutput: strongSelf)
        }
    }

    func presentYandexAuthModule(_ paymentOption: PaymentOption) {
        let moduleInputData = YandexAuthModuleInputData(tokenizationSettings: inputData.tokenizationSettings,
                                                        testModeSettings: inputData.testModeSettings,
                                                        clientApplicationKey: inputData.clientApplicationKey,
                                                        gatewayId: inputData.gatewayId,
                                                        amount: MonetaryAmountFactory.makeAmount(paymentOption.charge),
                                                        isLoggingEnabled: inputData.isLoggingEnabled)
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.presentYandexAuth(inputData: moduleInputData,
                                                moduleOutput: strongSelf)
        }
    }

    func tokenize(_ data: TokenizeData, paymentOption: PaymentOption) {
        tokenizeData = data
        interactor.tokenize(data, paymentOption: paymentOption)
    }

    func loginInYandexMoney(reusableToken: Bool, paymentOption: PaymentOption) {
        interactor.loginInYandexMoney(reusableToken: reusableToken, paymentOption: paymentOption)
    }

    func logout(accountId: String) {
        let accountName = interactor.getYandexDisplayName()
        let inputData = LogoutConfirmationModuleInputData(accountName: accountName ?? accountId)
        router.presentLogoutConfirmation(inputData: inputData,
                                         moduleOutput: self)
    }

    func presentApplePay(_ paymentOption: PaymentOption) {
        let moduleInputData = ApplePayModuleInputData(merchantIdentifier: inputData.applePayMerchantIdentifier,
                                                      amount: MonetaryAmountFactory.makeAmount(paymentOption.charge),
                                                      shopName: inputData.shopName,
                                                      purchaseDescription: inputData.purchaseDescription,
                                                      supportedNetworks: ApplePayConstants.paymentNetworks,
                                                      fee: paymentOption.fee)
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.presentApplePay(inputData: moduleInputData,
                                              moduleOutput: strongSelf)
        }
    }

    func presentApplePayContract(_ paymentOption: PaymentOption) {
        let viewModel = makePaymentMethodViewModel(paymentOption: paymentOption)
        let moduleInputData = ApplePayContractModuleInputData(
            shopName: inputData.shopName,
            purchaseDescription: inputData.purchaseDescription,
            paymentMethod: viewModel,
            price: makePriceViewModel(paymentOption),
            fee: makeFeePriceViewModel(paymentOption),
            shouldChangePaymentMethod: shouldChangePaymentOptions,
            testModeSettings: inputData.testModeSettings,
            isLoggingEnabled: inputData.isLoggingEnabled,
            termsOfService: termsOfService
        )

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.presentApplePayContract(inputData: moduleInputData,
                                                      moduleOutput: strongSelf)
        }
    }

    func presentErrorWithMessage(_ message: String) {
        let moduleInputData = ErrorModuleInputData(errorTitle: message)
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.presentError(inputData: moduleInputData,
                                           moduleOutput: strongSelf)
        }
    }

    func didFinish(on module: TokenizationStrategyInput) {
        handleOnePaymentOptionMethodAtReturn()
    }

    func handleOnePaymentOptionMethodAtReturn() {
        if paymentOptionsCount == Constants.minimalRecommendedPaymentsOptions {
            close()
        } else {
            presentPaymentMethodsModule()
        }
    }

    func presentTermsOfServiceModule(_ url: URL) {
        router.presentTermsOfServiceModule(url)
    }
}

// MARK: - TokenizationViewOutput

extension TokenizationPresenter: TokenizationViewOutput {
    func closeDidPress() {
        close()
    }

    func setupView() {
        view?.setCustomizationSettings(inputData.customizationSettings)
        interactor.startAnalyticsService()
        presentPaymentMethodsModule()
    }
}

// MARK: - TokenizationInteractorOutput

extension TokenizationPresenter: TokenizationInteractorOutput {
    func didTokenizeData(_ token: Tokens) {
        guard let paymentOption = paymentOption,
              let tokenizeData = tokenizeData else { return }

        let event = makeAnalyticsEventFromTokenizeData(tokenizeData)
        interactor.trackEvent(event)
        interactor.stopAnalyticsService()

        moduleOutput?.tokenizationModule(self,
                                         didTokenize: token,
                                         paymentMethodType: paymentOption.paymentMethodType)
    }

    func failTokenizeData(_ error: Error) {
        strategy?.failTokenizeData(error)
    }

    func didLoginInYandexMoney(_ response: YamoneyLoginResponse) {
        strategy?.didLoginInYandexMoney(response)

        if case .authorized = response {
            DispatchQueue.global().async { [weak self] in
                guard let interactor = self?.interactor else { return }
                interactor.trackEvent(.actionPaymentAuthorization(.success))
            }
        }
    }

    func failLoginInYandexMoney(_ error: Error) {
        strategy?.failLoginInYandexMoney(error)

        DispatchQueue.global().async { [weak self] in
            guard let interactor = self?.interactor else { return }
            interactor.trackEvent(.actionPaymentAuthorization(.fail))
        }
    }

    func didResendSmsCode(_ authTypeState: AuthTypeState) {
        yamoneyAuthModule?.setAuthTypeState(authTypeState)
    }

    func failResendSmsCode(_ error: Error) {
        yamoneyAuthModule?.failResendSmsCode(error)
    }

    private func makeAnalyticsEventFromTokenizeData(_ tokenizeData: TokenizeData) -> AnalyticsEvent {

        let scheme: AnalyticsEvent.TokenizeScheme
        let type = interactor.makeTypeAnalyticsParameters()

        switch tokenizeData {
        case .bankCard:
            scheme = .bankCard
        case .wallet:
            scheme = .wallet
        case .linkedBankCard:
            scheme = .linkedCard
        case .applePay:
            scheme = .applePay
        case .sberbank:
            scheme = .smsSbol
        }

        let event: AnalyticsEvent = .actionTokenize(scheme: scheme,
                                                    authType: type.authType,
                                                    tokenType: type.tokenType)
        return event
    }
}

// MARK: - TokenizationModuleInput

extension TokenizationPresenter: TokenizationModuleInput {
    func start3dsProcess(requestUrl: String, redirectUrl: String) {
        let moduleInputData
            = CardSecModuleInputData(requestUrl: requestUrl,
                                     redirectUrl: inputData.returnUrl ?? Constants.returnUrl,
                                     isLoggingEnabled: inputData.isLoggingEnabled)
        present3dsModule(inputData: moduleInputData)
    }

    func start3dsProcess(requestUrl: String) {
        let moduleInputData
            = CardSecModuleInputData(requestUrl: requestUrl,
                                     redirectUrl: inputData.returnUrl ?? Constants.returnUrl,
                                     isLoggingEnabled: inputData.isLoggingEnabled)
        present3dsModule(inputData: moduleInputData)
    }
}

// MARK: - PaymentMethodsModuleOutput

extension TokenizationPresenter: PaymentMethodsModuleOutput {
    func paymentMethodsModule(_ module: PaymentMethodsModuleInput,
                              didSelect paymentOption: PaymentOption,
                              methodsCount: Int) {
        paymentOptionsCount = methodsCount
        paymentMethodsModuleInput = module

        if paymentOption is PaymentInstrumentYandexMoneyWallet ||
               paymentOption is PaymentInstrumentYandexMoneyLinkedBankCard ||
               paymentOption.paymentMethodType == .bankCard ||
               paymentOption.paymentMethodType == .sberbank ||
               paymentOption.paymentMethodType == .applePay {

            self.paymentOption = paymentOption
            strategy?.beginProcess()

        } else if paymentOption.paymentMethodType == .yandexMoney {
            presentYandexAuthModule(paymentOption)
        }
    }

    func paymentMethodsModule(_ module: PaymentMethodsModuleInput,
                              didPressLogout paymentOption: PaymentInstrumentYandexMoneyWallet) {
        logout(accountId: paymentOption.accountId)
        self.paymentOption = nil
    }

    func didFinish(on module: PaymentMethodsModuleInput) {
        close()
    }
}

// MARK: - ContractModuleOutput

extension TokenizationPresenter: ContractModuleOutput {
    func didPressSubmitButton(on module: ContractModuleInput) {
        strategy?.didPressSubmitButton(on: module)
    }

    func didPressChangeAction(on module: ContractModuleInput) {
        interactor.trackEvent(.actionChangePaymentMethod)
        presentPaymentMethodsModule()
    }

    func didFinish(on module: ContractModuleInput) {
        close()
    }

    func didPressLogoutButton(on module: ContractModuleInput) {
        strategy?.didPressLogout()
    }

    func contractModule(_ module: ContractModuleInput, didTapTermsOfService url: URL) {
        presentTermsOfServiceModule(url)
    }
}

// MARK: - SberbankModuleOutput

extension TokenizationPresenter: SberbankModuleOutput {

    func sberbank(_ module: SberbankModuleInput, phoneNumber: String) {
        strategy?.sberbankModule(module, didPressConfirmButton: phoneNumber)
    }

    func didFinish(on module: SberbankModuleInput) {
        close()
    }

    func didPressChangeAction(on module: SberbankModuleInput) {
        interactor.trackEvent(.actionChangePaymentMethod)
        presentPaymentMethodsModule()
    }

    func sberbank(_ module: SberbankModuleInput, didTapTermsOfService url: URL) {
        presentTermsOfServiceModule(url)
    }
}

// MARK: - BankCardDataInputModuleOutput

extension TokenizationPresenter: BankCardDataInputModuleOutput {
    func bankCardDataInputModule(_ module: BankCardDataInputModuleInput,
                                 didPressConfirmButton bankCardData: CardData) {
        DispatchQueue.global().async { [weak self] in
            guard let strategy = self?.strategy else { return }
            strategy.bankCardDataInputModule(module, didPressConfirmButton: bankCardData)
        }
    }

    func didPressCloseBarButtonItem(on module: BankCardDataInputModuleInput) {
        if paymentOptionsCount > Constants.minimalRecommendedPaymentsOptions {
            presentPaymentMethodsModule()
        } else {
            close()
        }
    }
}

// MARK: - MaskedBankCardDataInputModuleOutput

extension TokenizationPresenter: MaskedBankCardDataInputModuleOutput {
    func didPressConfirmButton(on module: BankCardDataInputModuleInput,
                               cvc: String) {
        DispatchQueue.global().async { [weak self] in
            guard let strategy = self?.strategy else { return }
            strategy.didPressConfirmButton(on: module, cvc: cvc)
        }
    }
}

// MARK: - YandexAuthModuleOutput

extension TokenizationPresenter: YandexAuthModuleOutput {

    func yandexAuthModule(_ module: YandexAuthModuleInput, didFetchYamoneyPaymentMethod paymentMethod: PaymentOption) {
        self.paymentOption = paymentMethod
        strategy?.beginProcess()
    }

    func didFetchYamoneyPaymentMethods(on module: YandexAuthModuleInput) {
        presentPaymentMethodsModule()
    }

    func didFetchYamoneyPaymentMethodsWithoutWallet(on module: YandexAuthModuleInput) {
        interactor.trackEvent(.actionAuthWithoutWallet)
        presentPaymentMethodsModule()
    }

    func didFailFetchYamoneyPaymentMethods(on module: YandexAuthModuleInput) {}

    func didCancelAuthorizeInYandex(on module: YandexAuthModuleInput) {
        handleOnePaymentOptionMethodAtReturn()
    }
}

// MARK: - YamoneyAuthParametersModuleOutput

extension TokenizationPresenter: YamoneyAuthParametersModuleOutput {
    func yamoneyAuthParameters(_ module: YamoneyAuthParametersModuleInput,
                               loginWithReusableToken isReusableToken: Bool) {
        DispatchQueue.global().async { [weak self] in
            guard let strongSelf = self,
                  let strategy = strongSelf.strategy else { return }
            strongSelf.isReusableToken = isReusableToken
            strategy.yamoneyAuthParameters(module,
                                           loginWithReusableToken: isReusableToken)
        }
    }

    func didFinish(on module: YamoneyAuthParametersModuleInput) {
        close()
    }

    func didPressLogoutButton(on module: YamoneyAuthParametersModuleInput) {
        strategy?.didPressLogout()
    }

    func didPressChangeAction(on module: YamoneyAuthParametersModuleInput) {
        DispatchQueue.global().async { [weak self] in
            guard let interactor = self?.interactor else { return }
            interactor.trackEvent(.actionChangePaymentMethod)
        }

        presentPaymentMethodsModule()
    }

    func yamoneyAuthParameters(_ module: YamoneyAuthParametersModuleInput, didTapTermsOfService url: URL) {
        presentTermsOfServiceModule(url)
    }
}

// MARK: - YamoneyAuthModuleOutput

extension TokenizationPresenter: YamoneyAuthModuleOutput {
    func yamoneyAuth(_ module: YamoneyAuthModuleInput,
                     resendSmsCodeWithContextId authContextId: String,
                     authType: AuthType) {
        yamoneyAuthModule = module
        strategy?.contractStateHandler = module

        module.hidePlaceholder()
        module.showActivity()

        interactor.resendSmsCode(authContextId: authContextId,
                                 authType: authType)
    }

    func yamoneyAuth(_ module: YamoneyAuthModuleInput,
                     authContextId: String,
                     authType: AuthType,
                     answer: String,
                     processId: String) {
        yamoneyAuthModule = module

        strategy?.contractStateHandler = module
        module.hidePlaceholder()
        module.showActivity()

        interactor.loginInYandexMoney(authContextId: authContextId,
                                      authType: authType,
                                      answer: answer,
                                      processId: processId)
    }

    func didPressLogoutButton(on module: YamoneyAuthModuleInput) {
        strategy?.didPressLogout()
    }

    func didFinish(on module: YamoneyAuthModuleInput) {
        close()
    }

    func didPressChangeAction(on module: YamoneyAuthModuleInput) {
        DispatchQueue.global().async { [weak self] in
            guard let interactor = self?.interactor else { return }
            interactor.trackEvent(.actionChangePaymentMethod)
        }

        presentPaymentMethodsModule()
    }

    func yamoneyAuth(_ module: YamoneyAuthModuleInput, didFinishWithError error: Error) {
        guard let isReusableToken = isReusableToken,
              let paymentOption = paymentOption else { return }
        loginInYandexMoney(
            reusableToken: isReusableToken,
            paymentOption: paymentOption
        )
    }

    func yamoneyAuth(_ module: YamoneyAuthModuleInput, didTapTermsOfService url: URL) {
        presentTermsOfServiceModule(url)
    }
}

// MARK: - LogoutConfirmationModuleOutput

extension TokenizationPresenter: LogoutConfirmationModuleOutput {
    func logoutDidConfirm(on module: LogoutConfirmationModuleInput) {
        DispatchQueue.global().async { [weak self] in
            guard let interactor = self?.interactor else { return }
            interactor.logout()
            interactor.trackEvent(.actionLogout)

            DispatchQueue.main.async {
                guard let strongSelf = self else { return }
                strongSelf.paymentOption = nil
                strongSelf.strategy = nil
                strongSelf.presentPaymentMethodsModule()
            }
        }
    }

    func logoutDidCancel(on module: LogoutConfirmationModuleInput) {

    }
}

// MARK: - CardSecModuleOutput

extension TokenizationPresenter: CardSecModuleOutput {
    func didSuccessfullyPassedCardSec(on module: CardSecModuleInput) {
        moduleOutput?.didSuccessfullyPassedCardSec(on: self)
    }

    func didPressCloseButton(on module: CardSecModuleInput) {
        close()
    }
}

// MARK: - ApplePayModuleOutput

extension TokenizationPresenter: ApplePayModuleOutput {

    func didPresentApplePayModule() {
        strategy?.didPresentApplePayModule()
    }

    func didFailPresentApplePayModule() {
        strategy?.didFailPresentApplePayModule()
    }

    @available(iOS 11.0, *)
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
                                            didAuthorizePayment payment: PKPayment,
                                            handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        paymentAuthorizationViewController(controller, didAuthorizePayment: payment) { status in
            completion(PKPaymentAuthorizationResult(status: status, errors: nil))
        }
    }

    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
                                            didAuthorizePayment payment: PKPayment,
                                            completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        strategy?.paymentAuthorizationViewController(controller,
                                                     didAuthorizePayment: payment,
                                                     completion: completion)
    }

    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        strategy?.paymentAuthorizationViewControllerDidFinish(controller)
    }
}

// MARK: - ApplePayContractModuleOutput

extension TokenizationPresenter: ApplePayContractModuleOutput {
    func didFinish(on module: ApplePayContractModuleInput) {
        close()
    }

    func didPressChangeAction(on module: ApplePayContractModuleInput) {
        DispatchQueue.global().async { [weak self] in
            guard let interactor = self?.interactor else { return }
            interactor.trackEvent(.actionChangePaymentMethod)
        }

        presentPaymentMethodsModule()
    }

    func didPressSubmitButton(on module: ApplePayContractModuleInput) {
         strategy?.didPressSubmitButton(on: module)
    }

    func applePayContractModule(_ module: ApplePayContractModuleInput, didTapTermsOfService url: URL) {
        presentTermsOfServiceModule(url)
    }
}

// MARK: - ErrorModuleOutput

extension TokenizationPresenter: ErrorModuleOutput {

    func didPressPlaceholderButton(on module: ErrorModuleInput) {
        presentPaymentMethodsModule()
    }
}

// MARK: - Module helpers

private extension TokenizationPresenter {

    func close() {
        interactor?.stopAnalyticsService()
        moduleOutput?.didFinish(on: self, with: nil)
    }
}

private func makePriceViewModel(_ paymentOption: PaymentOption) -> PriceViewModel {
    let amountString = paymentOption.charge.value.description
    var integerPart = ""
    var fractionalPart = ""

    if let separatorIndex = amountString.firstIndex(of: ".") {
        integerPart = String(amountString[amountString.startIndex..<separatorIndex])
        fractionalPart = String(amountString[amountString.index(after: separatorIndex)..<amountString.endIndex])
    } else {
        integerPart = amountString
        fractionalPart = "00"
    }
    return TempAmount(currency: paymentOption.charge.currency.currencySymbol,
                      integerPart: integerPart,
                      fractionalPart: fractionalPart,
                      style: .amount)
}

private func makeFeePriceViewModel(_ paymentOption: PaymentOption) -> PriceViewModel? {
    guard let fee = paymentOption.fee, let service = fee.service else { return nil }

    let amountString = service.charge.value.description
    var integerPart = ""
    var fractionalPart = ""

    if let separatorIndex = amountString.firstIndex(of: ".") {
        integerPart = String(amountString[amountString.startIndex..<separatorIndex])
        fractionalPart = String(amountString[amountString.index(after: separatorIndex)..<amountString.endIndex])
    } else {
        integerPart = amountString
        fractionalPart = "00"
    }

    return TempAmount(currency: service.charge.currency.currencySymbol,
                      integerPart: integerPart,
                      fractionalPart: fractionalPart,
                      style: .fee)
}

private func makeStrategy(paymentOption: PaymentOption,
                          output: TokenizationStrategyOutput?,
                          testModeSettings: TestModeSettings?,
                          paymentMethodsModuleInput: PaymentMethodsModuleInput?,
                          returnUrl: String,
                          isLoggingEnabled: Bool) -> TokenizationStrategyInput {

    let authorizationService = AuthorizationProcessingAssembly
        .makeService(isLoggingEnabled: isLoggingEnabled,
                     testModeSettings: testModeSettings)

    let analyticsService = AnalyticsProcessingAssembly
        .makeAnalyticsService(isLoggingEnabled: isLoggingEnabled)

    let analyticsProvider = AnalyticsProvidingAssembly
        .makeAnalyticsProvider(isLoggingEnabled: isLoggingEnabled,
                               testModeSettings: testModeSettings)

    let strategy: TokenizationStrategyInput
    if let bankCard = try? BankCardStrategy(paymentOption: paymentOption, returnUrl: returnUrl) {
        strategy = bankCard
    } else if let wallet = try? WalletStrategy(authorizationService: authorizationService,
                                               paymentOption: paymentOption, returnUrl: returnUrl) {
        strategy = wallet
    } else if let linkedBankCard = try? LinkedBankCardStrategy(authorizationService: authorizationService,
                                                               paymentOption: paymentOption, returnUrl: returnUrl) {
        strategy = linkedBankCard
    } else if let sberbankStrategy = try? SberbankStrategy(paymentOption: paymentOption) {
        strategy = sberbankStrategy
    } else if let applePay = try? ApplePayStrategy(paymentOption: paymentOption,
                                                   paymentMethodsModuleInput: paymentMethodsModuleInput,
                                                   analyticsService: analyticsService,
                                                   analyticsProvider: analyticsProvider) {
        strategy = applePay
    } else {
        fatalError("Unsupported strategy")
    }
    strategy.output = output
    return strategy
}

// MARK: - Constants

private enum Constants {
    static let returnUrl = "https://custom.redirect.url/"
    static let minimalRecommendedPaymentsOptions = 1
}
