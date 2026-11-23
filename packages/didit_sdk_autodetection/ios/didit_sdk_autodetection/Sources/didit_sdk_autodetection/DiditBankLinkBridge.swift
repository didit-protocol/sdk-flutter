import Foundation
import UIKit
import DiditSDK

#if DIDIT_BANK_LINK

/// The hand-off into the native iOS Bank Link, written against the public API:
/// `DiditSdk.shared.presentBankLink(token:from:configuration:onEvent:onResult:)`,
/// `resumeBankLink(from:onEvent:onResult:)` and `handleBankLinkReturn(_:)`.
///
/// It is compiled only when the build defines `DIDIT_BANK_LINK`, which happens
/// in the same change that pins the native version carrying Bank Link; until
/// then `SdkFlutterPlugin` uses `UnavailableBankLinkBridge`. CI compiles and
/// tests this file from that pin on.
///
/// No parsing happens on this side: the token and the return address reach the
/// native SDK byte for byte, and every event and result field is mapped, never
/// re-derived, so a resume code that carries a dot survives the trip.
final class DiditBankLinkBridge: BankLinkBridging {

    /// Where a link is presented from: the top-most view controller of the
    /// app's key window. Injected so a test can answer "none".
    private let presenter: () -> UIViewController?

    init(presenter: @escaping () -> UIViewController? = { SdkFlutterPlugin.findRootViewController() }) {
        self.presenter = presenter
    }

    /// The presenting view controller is resolved here, never left to the
    /// native SDK: native logs and returns without opening a flow when it has
    /// none, and a flow that never reports a result would leave the Dart call
    /// waiting forever. With no view controller nothing is called and the
    /// answer is `false`, which Dart reads as a declined presentation.
    func present(
        token: String,
        configuration: DiditSdk.Configuration?,
        onEvent: @escaping (BankLinkWire.Event) -> Void,
        onResult: @escaping (BankLinkWire.Outcome) -> Void
    ) -> Bool {
        Self.onMainActor {
            guard let host = presenter() else { return false }
            return Self.opened(
                DiditSdk.shared.presentBankLink(
                    token: token,
                    from: host,
                    configuration: configuration,
                    onEvent: { event in
                        onEvent(BankLinkWire.Event(name: event.name.rawValue, payload: event.payload))
                    },
                    onResult: { result in
                        onResult(Self.outcome(result))
                    }
                )
            )
        }
    }

    /// With no view controller a resume cannot present, so it answers `false`
    /// (nothing resumed, `null` in Dart) instead of calling native.
    func resume(
        onEvent: @escaping (BankLinkWire.Event) -> Void,
        onResult: @escaping (BankLinkWire.Outcome) -> Void
    ) -> Bool {
        Self.onMainActor {
            guard let host = presenter() else { return false }
            return DiditSdk.shared.resumeBankLink(
                from: host,
                onEvent: { event in
                    onEvent(BankLinkWire.Event(name: event.name.rawValue, payload: event.payload))
                },
                onResult: { result in
                    onResult(Self.outcome(result))
                }
            )
        }
    }

    func handleReturn(_ url: String) -> Bool {
        guard let address = URL(string: url) else { return false }
        return Self.onMainActor {
            DiditSdk.shared.handleBankLinkReturn(address)
        }
    }

    /// `DiditSdk` is `@MainActor`. Flutter delivers method calls on the main
    /// thread, where the isolation is asserted without a hop; from any other
    /// thread the call hops synchronously to the main queue first.
    private static func onMainActor<T>(_ body: @MainActor () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated(body)
        }
        return DispatchQueue.main.sync { MainActor.assumeIsolated(body) }
    }

    /// Reads the answer of a native `presentBankLink` that returns `Bool`
    /// (`false` when nothing opened) and also compiles against one that returns
    /// nothing, which counts as opened.
    private static func opened<T>(_ nativeAnswer: T) -> Bool {
        (nativeAnswer as? Bool) ?? true
    }

    private static func outcome(_ result: BankLinkResult) -> BankLinkWire.Outcome {
        switch result {
        case .success(let success):
            return .success(
                linkId: success.linkId,
                connectionId: success.connectionId,
                checkId: success.checkId,
                resumed: success.resumed
            )
        case .exit(let exit):
            return .exit(
                reason: exit.reason.rawValue,
                step: exit.step?.rawValue,
                resumed: exit.resumed
            )
        @unknown default:
            return .exit(reason: "failed", step: nil, resumed: false)
        }
    }
}

#endif
