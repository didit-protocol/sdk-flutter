import Flutter
import UIKit
import SwiftUI
@preconcurrency import DiditSDK

public class SdkFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var hostingController: UIViewController?
    private var channel: FlutterMethodChannel?
    var bankLinkEvents: FlutterEventSink?
    private var presentationGeneration = 0
    private var hasDeliveredResult = false

    /// The Bank Link hand-off. The build picks the bridge of the pinned native
    /// version or the one that calls a native SDK carrying Bank Link; tests
    /// replace it with a fake native module.
    var bankLinkBridge: BankLinkBridging = BankLinkBridgeFactory.make()

    /// The link on screen, so a result reaches Dart exactly once.
    private var openBankLink: BankLinkCall?

    /// One `presentBankLink`/`resumeBankLink` call and its one answer to Dart.
    private final class BankLinkCall {
        let result: FlutterResult
        var delivered = false

        init(result: @escaping FlutterResult) {
            self.result = result
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "didit_sdk", binaryMessenger: registrar.messenger())
        let instance = SdkFlutterPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        let events = FlutterEventChannel(
            name: "didit_sdk/bank_link_events",
            binaryMessenger: registrar.messenger()
        )
        events.setStreamHandler(instance)
    }

    // MARK: - Bank Link events

    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        bankLinkEvents = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        bankLinkEvents = nil
        return nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startVerification":
            handleStartVerification(call, result: result)
        case "startVerificationWithWorkflow":
            handleStartVerificationWithWorkflow(call, result: result)
        case "submitTransaction":
            handleSubmitTransaction(call, result: result)
        case "getTransaction":
            handleGetTransaction(call, result: result)
        case "presentBankLink":
            handlePresentBankLink(call, result: result)
        case "resumeBankLink":
            handleResumeBankLink(result: result)
        case "handleBankLinkReturn":
            handleBankLinkReturn(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Start Verification with Token

    private func handleStartVerification(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let token = args["token"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Token is required", details: nil))
            return
        }

        let config = parseConfiguration(args["config"] as? [String: Any])

        DispatchQueue.main.async { [weak self] in
            self?.presentVerification(result: result) {
                MainActor.assumeIsolated {
                    DiditSdk.shared.startVerification(
                        token: token,
                        configuration: config
                    )
                }
            }
        }
    }

    // MARK: - Start Verification with Workflow

    private func handleStartVerificationWithWorkflow(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let workflowId = args["workflowId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Workflow ID is required", details: nil))
            return
        }

        let config = parseConfiguration(args["config"] as? [String: Any])

        DispatchQueue.main.async { [weak self] in
            self?.presentVerification(result: result) {
                MainActor.assumeIsolated {
                    DiditSdk.shared.startVerification(
                        workflowId: workflowId,
                        vendorData: args["vendorData"] as? String,
                        configuration: config
                    )
                }
            }
        }
    }

    // MARK: - Bank Link

    // The wrapper adds no flow of its own: the native SDK owns every screen of
    // Bank Link, its copy and its state machine. The plugin owns the seam: it
    // hands the token and the configuration over, forwards every event to the
    // `didit_sdk/bank_link_events` channel, and settles the Dart future with
    // the one result the native flow delivers.

    func handlePresentBankLink(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let token = args["token"] as? String,
              !token.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Token is required", details: nil))
            return
        }
        // One link at a time, like a verification: a second call settles as a
        // failed exit instead of opening a second flow.
        guard openBankLink == nil else {
            result(BankLinkWire.Outcome.exit(reason: "failed", step: nil, resumed: false).map)
            return
        }

        let options = args["options"] as? [String: Any]
        let configuration = parseConfiguration(options?["config"] as? [String: Any])
        let link = BankLinkCall(result: result)
        openBankLink = link

        let started = bankLinkBridge.present(
            token: token,
            configuration: configuration,
            onEvent: { [weak self] event in self?.emitBankLinkEvent(event) },
            onResult: { [weak self] outcome in self?.resolveBankLink(link, outcome: outcome) }
        )

        if !started {
            if openBankLink === link { openBankLink = nil }
            if !link.delivered {
                result(FlutterError(
                    code: "unavailable",
                    message: "This version of the native Didit SDK does not carry Bank Link.",
                    details: nil
                ))
            }
        }
    }

    func handleResumeBankLink(result: @escaping FlutterResult) {
        // One link at a time: native keeps one set of callbacks, so resuming
        // over an open link or another resume would hand the running flow's
        // result to this call and leave the earlier one unanswered.
        guard openBankLink == nil else {
            result(nil)
            return
        }

        let link = BankLinkCall(result: result)
        openBankLink = link

        let resumed = bankLinkBridge.resume(
            onEvent: { [weak self] event in self?.emitBankLinkEvent(event) },
            onResult: { [weak self] outcome in self?.resolveBankLink(link, outcome: outcome) }
        )

        if !resumed {
            if openBankLink === link { openBankLink = nil }
            // Nothing pending: a native layer without Bank Link kept no link,
            // and Dart reads nil as "nothing pending". Marked answered, so a
            // late native callback cannot answer this call a second time.
            if !link.delivered {
                link.delivered = true
                result(nil)
            }
        }
    }

    func handleBankLinkReturn(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let url = args["url"] as? String,
              !url.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "url is required", details: nil))
            return
        }
        // The address reaches the native handler unchanged: a resume code
        // carries a dot and arrives in a query parameter, so nothing here
        // splits or validates it.
        result(bankLinkBridge.handleReturn(url))
    }

    /// Every event of the running link, ids only, in the contract's shape.
    private func emitBankLinkEvent(_ event: BankLinkWire.Event) {
        bankLinkEvents?(event.map)
    }

    /// The one result of one call: a late or repeated answer is dropped.
    private func resolveBankLink(_ link: BankLinkCall, outcome: BankLinkWire.Outcome) {
        guard !link.delivered else { return }
        link.delivered = true
        if openBankLink === link { openBankLink = nil }
        link.result(outcome.map)
    }

    // MARK: - Presentation Logic

    private func presentVerification(result: @escaping FlutterResult, startAction: @escaping () -> Void) {
        removeStaleHostIfPresent()
        let generation = beginPresentation()

        guard let rootVC = Self.findRootViewController() else {
            result([
                "type": "failed",
                "errorType": "unknown",
                "errorMessage": "Unable to find root view controller to present verification UI."
            ])
            return
        }

        let bridgeView = DiditBridgeView(
            onResult: { [weak self] verificationResult in
                guard let self = self, self.claimResultDelivery(for: generation) else { return }
                self.tearDownThenResolve(
                    generation: generation,
                    mapped: Self.mapVerificationResult(verificationResult),
                    result: result
                )
            }
        )

        let hostingVC = UIHostingController(rootView: bridgeView)
        hostingVC.modalPresentationStyle = .overFullScreen
        hostingVC.view.backgroundColor = .clear
        self.hostingController = hostingVC

        presentHostThenStartFlow(hostingVC, from: rootVC, startFlow: startAction)
    }

    private func removeStaleHostIfPresent() {
        guard let stale = hostingController else { return }
        Self.dismissFromPresenter(stale)
        hostingController = nil
    }

    private func beginPresentation() -> Int {
        presentationGeneration += 1
        hasDeliveredResult = false
        return presentationGeneration
    }

    private func claimResultDelivery(for generation: Int) -> Bool {
        guard !hasDeliveredResult, presentationGeneration == generation else { return false }
        hasDeliveredResult = true
        return true
    }

    private func tearDownThenResolve(
        generation: Int,
        mapped: [String: Any?],
        result: @escaping FlutterResult
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard self.presentationGeneration == generation,
                  let host = self.hostingController else {
                result(mapped)
                return
            }
            Self.dismissFromPresenter(host) {
                self.hostingController = nil
                result(mapped)
            }
        }
    }

    private func presentHostThenStartFlow(
        _ host: UIViewController,
        from presenter: UIViewController,
        startFlow: @escaping () -> Void
    ) {
        presenter.present(host, animated: false, completion: startFlow)
    }

    // MARK: - View Controller Helpers

    static func findRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            return nil
        }

        return topmostPresentedController(startingFrom: rootVC)
    }

    private static func topmostPresentedController(startingFrom root: UIViewController) -> UIViewController {
        var controller = root
        while let presented = controller.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }

    private static func dismissFromPresenter(_ controller: UIViewController, completion: (() -> Void)? = nil) {
        (controller.presentingViewController ?? controller).dismiss(animated: false, completion: completion)
    }

    // MARK: - Configuration Parsing

    func parseConfiguration(_ dict: [String: Any]?) -> DiditSdk.Configuration? {
        guard let dict = dict else { return nil }

        var language: SupportedLanguage?
        if let code = dict["languageCode"] as? String {
            language = SupportedLanguage.allCases.first { $0.code == code }
        }

        let defaultDocumentCamera = Self.parseCameraLens(dict["defaultDocumentCamera"] as? String) ?? .back
        let defaultLivenessCamera = Self.parseCameraLens(dict["defaultLivenessCamera"] as? String) ?? .front

        return DiditSdk.Configuration(
            languageLocale: language,
            fontFamily: dict["fontFamily"] as? String,
            loggingEnabled: dict["loggingEnabled"] as? Bool ?? false,
            showCloseButton: dict["showCloseButton"] as? Bool ?? true,
            showExitConfirmation: dict["showExitConfirmation"] as? Bool ?? true,
            closeOnComplete: dict["closeOnComplete"] as? Bool ?? false,
            defaultDocumentCamera: defaultDocumentCamera,
            defaultLivenessCamera: defaultLivenessCamera,
            showDocumentCameraSwitchButton: dict["showDocumentCameraSwitchButton"] as? Bool ?? true,
            showLivenessCameraSwitchButton: dict["showLivenessCameraSwitchButton"] as? Bool ?? true,
            showLanguageSelector: dict["showLanguageSelector"] as? Bool ?? false
        )
    }

    private static func parseCameraLens(_ value: String?) -> CameraLens? {
        switch value?.lowercased() {
        case "front": return .front
        case "back": return .back
        default: return nil
        }
    }

    // MARK: - Result Mapping

    private static func statusString(_ status: VerificationStatus) -> String {
        switch status {
        case .approved: return "Approved"
        case .pending: return "Pending"
        case .declined: return "Declined"
        @unknown default: return "Pending"
        }
    }

    static func mapVerificationResult(_ result: VerificationResult) -> [String: Any?] {
        switch result {
        case .completed(let session):
            return [
                "type": "completed",
                "sessionId": session.sessionId,
                "status": statusString(session.status)
            ]

        case .cancelled(let session):
            var dict: [String: Any?] = ["type": "cancelled"]
            if let session = session {
                dict["sessionId"] = session.sessionId
                dict["status"] = statusString(session.status)
            }
            return dict

        case .failed(let error, let session):
            var dict: [String: Any?] = [
                "type": "failed",
                "errorType": mapErrorType(error),
                "errorMessage": error.localizedDescription
            ]
            if let session = session {
                dict["sessionId"] = session.sessionId
                dict["status"] = statusString(session.status)
            }
            return dict

        @unknown default:
            return [
                "type": "failed",
                "errorType": "unknown",
                "errorMessage": "Unrecognized verification result"
            ]
        }
    }

    private static func mapErrorType(_ error: VerificationError) -> String {
        switch error {
        case .sessionExpired: return "sessionExpired"
        case .retryBlocked: return "retryBlocked"
        case .networkError: return "networkError"
        case .cameraAccessDenied: return "cameraAccessDenied"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Transactions

    private func handleSubmitTransaction(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let transactionToken = args["transactionToken"] as? String,
              let transaction = args["transaction"] as? [String: Any],
              let txnId = transaction["txnId"] as? String, !txnId.isEmpty else {
            result(FlutterError(
                code: "validation",
                message: "transactionToken and transaction.txnId are required",
                details: nil
            ))
            return
        }
        let optionsDict = args["options"] as? [String: Any] ?? [:]
        let callId = optionsDict["callId"] as? String ?? ""
        let payload = Self.transactionPayload(txnId: txnId, from: transaction)
        let channel = self.channel
        let options = DiditTransactionOptions(
            baseUrl: optionsDict["baseUrl"] as? String,
            autoLaunchAction: optionsDict["autoLaunchAction"] as? Bool ?? true,
            onTransactionUpdated: { updated in
                channel?.invokeMethod(
                    "onTransactionUpdated",
                    arguments: [
                        "callId": callId,
                        "result": Self.transactionResultMap(updated)
                    ]
                )
            }
        )
        Task { @MainActor in
            do {
                let transactionResult = try await DiditSdk.shared.submitTransaction(
                    transactionToken: transactionToken,
                    transaction: payload,
                    options: options
                )
                result(Self.transactionResultMap(transactionResult))
            } catch {
                result(Self.transactionFlutterError(error))
            }
        }
    }

    private func handleGetTransaction(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let transactionToken = args["transactionToken"] as? String,
              let transactionId = args["transactionId"] as? String else {
            result(FlutterError(
                code: "validation",
                message: "transactionToken and transactionId are required",
                details: nil
            ))
            return
        }
        let optionsDict = args["options"] as? [String: Any] ?? [:]
        let options = DiditTransactionOptions(baseUrl: optionsDict["baseUrl"] as? String)
        Task { @MainActor in
            do {
                let transactionResult = try await DiditSdk.shared.getTransaction(
                    transactionToken: transactionToken,
                    transactionId: transactionId,
                    options: options
                )
                result(Self.transactionResultMap(transactionResult))
            } catch {
                result(Self.transactionFlutterError(error))
            }
        }
    }

    // MARK: - Transaction Mapping

    private static func transactionPayload(txnId: String, from dict: [String: Any]) -> DiditTransactionPayload {
        DiditTransactionPayload(
            txnId: txnId,
            txnDate: dict["txnDate"] as? String,
            zoneId: dict["zoneId"] as? String,
            type: dict["type"] as? String,
            info: (dict["info"] as? [String: Any]).map(transactionInfo),
            subject: (dict["subject"] as? [String: Any]).map(transactionParticipant),
            counterparty: (dict["counterparty"] as? [String: Any]).map(transactionParticipant),
            props: dict["props"] as? [String: Any],
            travelRule: (dict["travelRule"] as? [String: Any]).map(travelRule),
            includeCryptoScreening: dict["includeCryptoScreening"] as? Bool
        )
    }

    private static func transactionInfo(_ dict: [String: Any]) -> DiditTransactionInfo {
        DiditTransactionInfo(
            direction: dict["direction"] as? String,
            amount: (dict["amount"] as? NSNumber)?.doubleValue,
            currency: dict["currency"] as? String,
            currencyType: dict["currencyType"] as? String,
            amountInDefaultCurrency: (dict["amountInDefaultCurrency"] as? NSNumber)?.doubleValue,
            defaultCurrencyCode: dict["defaultCurrencyCode"] as? String,
            paymentDetails: dict["paymentDetails"] as? String,
            paymentTxnId: dict["paymentTxnId"] as? String,
            type: dict["type"] as? String,
            cryptoParams: dict["cryptoParams"] as? [String: Any]
        )
    }

    private static func transactionParticipant(_ dict: [String: Any]) -> DiditTransactionParticipant {
        DiditTransactionParticipant(
            type: dict["type"] as? String,
            externalUserId: dict["externalUserId"] as? String,
            fullName: dict["fullName"] as? String,
            firstName: dict["firstName"] as? String,
            lastName: dict["lastName"] as? String,
            dob: dict["dob"] as? String,
            address: dict["address"] as? [String: Any],
            institutionInfo: dict["institutionInfo"] as? [String: Any],
            device: dict["device"] as? [String: Any],
            paymentMethod: (dict["paymentMethod"] as? [String: Any]).map { method in
                DiditTransactionPaymentMethod(
                    type: method["type"] as? String,
                    accountId: method["accountId"] as? String,
                    issuingCountry: method["issuingCountry"] as? String
                )
            }
        )
    }

    private static func travelRule(_ dict: [String: Any]) -> DiditTravelRuleInfo {
        DiditTravelRuleInfo(
            status: dict["status"] as? String,
            `protocol`: dict["protocol"] as? String,
            required: dict["required"] as? Bool,
            obligationsCount: (dict["obligationsCount"] as? NSNumber)?.intValue,
            originatorData: dict["originatorData"] as? [String: Any],
            beneficiaryData: dict["beneficiaryData"] as? [String: Any],
            metadata: dict["metadata"] as? [String: Any]
        )
    }

    private static func transactionResultMap(_ result: DiditTransactionResult) -> [String: Any] {
        var map: [String: Any] = ["transactionId": result.transactionId]
        map["status"] = result.status
        map["travelRuleStatus"] = result.travelRuleStatus
        if let action = result.actionRequired {
            var actionMap: [String: Any] = ["type": action.type]
            actionMap["url"] = action.url
            actionMap["sessionId"] = action.sessionId
            actionMap["sessionToken"] = action.sessionToken
            actionMap["status"] = action.status
            actionMap["widgetSessionId"] = action.widgetSessionId
            actionMap["expiresAt"] = action.expiresAt
            map["actionRequired"] = actionMap
        }
        return map
    }

    private static func transactionFlutterError(_ error: Error) -> FlutterError {
        guard let transactionError = error as? DiditTransactionError else {
            return FlutterError(code: "network", message: error.localizedDescription, details: nil)
        }
        let message = transactionError.errorDescription
        switch transactionError {
        case .invalidToken:
            return FlutterError(code: "invalid_token", message: message, details: nil)
        case .expiredToken:
            return FlutterError(code: "expired_token", message: message, details: nil)
        case .validation(let fieldErrors):
            let details = JSONSerialization.isValidJSONObject(fieldErrors) ? fieldErrors : ["detail": message ?? "Validation error"]
            return FlutterError(code: "validation", message: message, details: details)
        case .network:
            return FlutterError(code: "network", message: message, details: nil)
        }
    }
}

// MARK: - SwiftUI Bridge View

private struct DiditBridgeView: View {
    let onResult: (VerificationResult) -> Void

    var body: some View {
        Color.clear
            .edgesIgnoringSafeArea(.all)
            .diditVerification { result in
                onResult(result)
            }
    }
}
