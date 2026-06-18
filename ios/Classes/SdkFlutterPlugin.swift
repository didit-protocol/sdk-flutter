import Flutter
import UIKit
import SwiftUI
@preconcurrency import DiditSDK

public class SdkFlutterPlugin: NSObject, FlutterPlugin {

    private var hostingController: UIViewController?
    private var presentationGeneration = 0
    private var hasDeliveredResult = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "didit_sdk", binaryMessenger: registrar.messenger())
        let instance = SdkFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startVerification":
            handleStartVerification(call, result: result)
        case "startVerificationWithWorkflow":
            handleStartVerificationWithWorkflow(call, result: result)
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

    private static func findRootViewController() -> UIViewController? {
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

    private func parseConfiguration(_ dict: [String: Any]?) -> DiditSdk.Configuration? {
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
            showLivenessCameraSwitchButton: dict["showLivenessCameraSwitchButton"] as? Bool ?? true
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

    private static func mapVerificationResult(_ result: VerificationResult) -> [String: Any?] {
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
        case .networkError: return "networkError"
        case .cameraAccessDenied: return "cameraAccessDenied"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
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
