import Flutter
import UIKit
import SwiftUI
import DiditSDK

public class SdkFlutterPlugin: NSObject, FlutterPlugin {

    private var hostingController: UIViewController?

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
                DiditSdk.shared.startVerification(
                    token: token,
                    configuration: config
                )
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
        let contact = parseContactDetails(args["contactDetails"] as? [String: Any])
        let expected = parseExpectedDetails(args["expectedDetails"] as? [String: Any])

        DispatchQueue.main.async { [weak self] in
            self?.presentVerification(result: result) {
                DiditSdk.shared.startVerification(
                    workflowId: workflowId,
                    vendorData: args["vendorData"] as? String,
                    metadata: args["metadata"] as? String,
                    contactDetails: contact,
                    expectedDetails: expected,
                    configuration: config
                )
            }
        }
    }

    // MARK: - Presentation Logic

    private func presentVerification(result: @escaping FlutterResult, startAction: @escaping () -> Void) {
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
                let mapped = Self.mapVerificationResult(verificationResult)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.hostingController?.dismiss(animated: false) {
                        self?.hostingController = nil
                    }
                }

                result(mapped)
            },
            startAction: startAction
        )

        let hostingVC = UIHostingController(rootView: bridgeView)
        hostingVC.modalPresentationStyle = .overFullScreen
        hostingVC.view.backgroundColor = .clear
        self.hostingController = hostingVC

        rootVC.present(hostingVC, animated: false)
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

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }

    // MARK: - Configuration Parsing

    private func parseConfiguration(_ dict: [String: Any]?) -> DiditSdk.Configuration? {
        guard let dict = dict else { return nil }

        var language: SupportedLanguage?
        if let code = dict["languageCode"] as? String {
            language = SupportedLanguage.allCases.first { $0.code == code }
        }

        return DiditSdk.Configuration(
            languageLocale: language,
            fontFamily: dict["fontFamily"] as? String,
            loggingEnabled: dict["loggingEnabled"] as? Bool ?? false
        )
    }

    private func parseContactDetails(_ dict: [String: Any]?) -> ContactDetails? {
        guard let dict = dict else { return nil }

        return ContactDetails(
            email: dict["email"] as? String,
            sendNotificationEmails: dict["sendNotificationEmails"] as? Bool,
            emailLang: dict["emailLang"] as? String,
            phone: dict["phone"] as? String
        )
    }

    private func parseExpectedDetails(_ dict: [String: Any]?) -> ExpectedDetails? {
        guard let dict = dict else { return nil }

        return ExpectedDetails(
            firstName: dict["firstName"] as? String,
            lastName: dict["lastName"] as? String,
            dateOfBirth: dict["dateOfBirth"] as? String,
            gender: dict["gender"] as? String,
            nationality: dict["nationality"] as? String,
            country: dict["country"] as? String,
            address: dict["address"] as? String,
            identificationNumber: dict["identificationNumber"] as? String,
            ipAddress: dict["ipAddress"] as? String,
            portraitImage: dict["portraitImage"] as? String
        )
    }

    // MARK: - Result Mapping

    private static func statusString(_ status: VerificationStatus) -> String {
        switch status {
        case .approved: return "Approved"
        case .pending: return "Pending"
        case .declined: return "Declined"
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
        }
    }

    private static func mapErrorType(_ error: VerificationError) -> String {
        switch error {
        case .sessionExpired: return "sessionExpired"
        case .networkError: return "networkError"
        case .cameraAccessDenied: return "cameraAccessDenied"
        case .unknown: return "unknown"
        }
    }
}

// MARK: - SwiftUI Bridge View

private struct DiditBridgeView: View {
    let onResult: (VerificationResult) -> Void
    let startAction: () -> Void

    var body: some View {
        Color.clear
            .edgesIgnoringSafeArea(.all)
            .diditVerification { result in
                onResult(result)
            }
            .onAppear {
                startAction()
            }
    }
}
