import Flutter
import UIKit
#if canImport(DiditAuth)
@preconcurrency import DiditAuth
#else
// A DiditSDK source pod compiles DiditAuth into the DiditSDK module.
@preconcurrency import DiditSDK
#endif

/// Forwards every call of the `didit_auth` channel to native DiditAuth. Its error codes reach Dart
/// unchanged (see `DiditAuthWire`). Sessions and step-up results cross the channel as JSON text.
public class DiditAuthPlugin: NSObject, FlutterPlugin {
    // One DiditAuth per application, created and read on the main actor only.
    @MainActor private var instances: [String: DiditAuth] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "didit_auth", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(DiditAuthPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "signIn":
            forward(args, result) { auth in
                try DiditAuthWire.sessionJson(try await auth.signIn(from: try Self.presenter()))
            }
        case "signInWithPasskey":
            forward(args, result) { auth in
                try DiditAuthWire.sessionJson(try await auth.signInWithPasskey(from: try Self.presenter()))
            }
        case "reauthenticate":
            let method = args["method"] as? String
            forward(args, result) { auth in
                let reauthMethod = try DiditAuthWire.reauthMethod(method)
                return try DiditAuthWire.sessionJson(
                    try await auth.reauthenticate(method: reauthMethod, from: try Self.presenter())
                )
            }
        case "registerPasskey":
            forward(args, result) { auth in
                try await auth.registerPasskey(from: try Self.presenter())
            }
        case "currentSession":
            let force = args["force"] as? Bool ?? false
            forward(args, result) { auth in
                try await auth.currentSession(force: force).map { try DiditAuthWire.sessionJson($0) }
            }
        case "getToken":
            forward(args, result) { auth in
                try await auth.getToken()
            }
        case "signOut":
            forward(args, result) { auth in
                try await auth.signOut()
                return nil
            }
        case "stepUp":
            let action = args["action"] as? String
            let amount = args["amount"] as? String
            let currency = args["currency"] as? String
            forward(args, result) { auth in
                let stepUpAction = try DiditAuthWire.stepUpAction(action, amount: amount, currency: currency)
                return try DiditAuthWire.stepUpResultJson(try await auth.stepUp(stepUpAction, from: try Self.presenter()))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Runs `operation` on the main actor and answers `result` exactly once, with its value or its failure.
    private func forward(
        _ args: [String: Any],
        _ result: @escaping FlutterResult,
        _ operation: @escaping @MainActor (DiditAuth) async throws -> String?
    ) {
        Task { @MainActor in
            let value: String?
            do {
                value = try await operation(try self.auth(args))
            } catch {
                result(DiditAuthWire.flutterError(error))
                return
            }
            result(value)
        }
    }

    @MainActor
    private func auth(_ args: [String: Any]) throws -> DiditAuth {
        guard let publishableKey = args["publishableKey"] as? String else {
            throw DiditAuthError("invalid_publishable_key", "publishableKey is required.")
        }
        guard let redirectUri = args["redirectUri"] as? String else {
            throw DiditAuthError("invalid_redirect_uri", "redirectUri is required.")
        }
        let key = publishableKey + "\n" + redirectUri
        if let auth = instances[key] { return auth }
        let auth = try DiditAuth(publishableKey: publishableKey, redirectUri: redirectUri)
        instances[key] = auth
        return auth
    }

    /// The view controller in the foreground, read when the call starts; the hosted page and the
    /// passkey prompt are shown from it.
    @MainActor
    private static func presenter() throws -> UIViewController {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              var controller = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            throw DiditAuthError("browser_unavailable", "No screen is in the foreground to show the Didit page.")
        }
        while let presented = controller.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }
}
