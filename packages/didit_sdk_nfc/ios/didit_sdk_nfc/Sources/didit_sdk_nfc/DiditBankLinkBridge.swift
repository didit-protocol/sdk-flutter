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

    func present(
        token: String,
        configuration: DiditSdk.Configuration?,
        onEvent: @escaping (BankLinkWire.Event) -> Void,
        onResult: @escaping (BankLinkWire.Outcome) -> Void
    ) -> Bool {
        Self.onMainActor {
            DiditSdk.shared.presentBankLink(
                token: token,
                from: nil,
                configuration: configuration,
                onEvent: { event in
                    onEvent(BankLinkWire.Event(name: event.name.rawValue, payload: event.payload))
                },
                onResult: { result in
                    onResult(Self.outcome(result))
                }
            )
        }
        return true
    }

    func resume(
        onEvent: @escaping (BankLinkWire.Event) -> Void,
        onResult: @escaping (BankLinkWire.Outcome) -> Void
    ) -> Bool {
        return Self.onMainActor {
            DiditSdk.shared.resumeBankLink(
                from: nil,
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
