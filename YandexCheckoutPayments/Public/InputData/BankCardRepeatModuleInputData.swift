// Input data for repeat bank card tokenization flow.
public struct BankCardRepeatModuleInputData {

    /// Client application key.
    let clientApplicationKey: String

    /// Name of shop.
    let shopName: String

    /// Purchase description.
    let purchaseDescription: String

    /// The ID of the saved payment method.
    let paymentMethodId: String

    /// Amount of payment.
    let amount: Amount

    /// Test mode settings.
    let testModeSettings: TestModeSettings?

    /// Return url for close 3ds.
    let returnUrl: String?

    /// Enable logging
    let isLoggingEnabled: Bool

    /// Settings to customize SDK interface.
    let customizationSettings: CustomizationSettings

    /// Creates instance of `BankCardRepeatModuleInputData`.
    ///
    /// - Parameters:
    ///   - clientApplicationKey: Client application key.
    ///   - shopName: Name of shop.
    ///   - purchaseDescription: Purchase description.
    ///   - paymentMethodId: The ID of the saved payment method.
    ///   - amount: Amount of payment.
    ///   - testModeSettings: Test mode settings.
    ///   - returnUrl: Return url for close 3ds.
    ///   - isLoggingEnabled: Enable logging
    ///   - customizationSettings: Settings to customize SDK interface.
    ///
    /// - Returns: Instance of `BankCardRepeatModuleInputData`.
    public init(
        clientApplicationKey: String,
        shopName: String,
        purchaseDescription: String,
        paymentMethodId: String,
        amount: Amount,
        testModeSettings: TestModeSettings? = nil,
        returnUrl: String? = nil,
        isLoggingEnabled: Bool = false,
        customizationSettings: CustomizationSettings = CustomizationSettings()
    ) {
        self.clientApplicationKey = (clientApplicationKey + ":").base64Encoded()
        self.shopName = shopName
        self.purchaseDescription = purchaseDescription
        self.paymentMethodId = paymentMethodId
        self.amount = amount
        self.testModeSettings = testModeSettings
        self.returnUrl = returnUrl
        self.isLoggingEnabled = isLoggingEnabled
        self.customizationSettings = customizationSettings
    }
}
