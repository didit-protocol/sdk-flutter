import Foundation
import UIKit
import DiditSDK

/// What the plugin needs from a Bank Link, independent of the native SDK
/// version it is built against.
///
/// The wrapper adds no flow of its own: the native SDK owns every screen of a
/// link, its copy and its state machine. This protocol is only the seam between
/// that flow and the method and event channels, so the mapping Dart depends on
/// is compiled and tested while the released native SDK still has no Bank Link.
///
/// Which implementation the plugin gets is chosen by `BankLinkBridgeFactory`:
/// `UnavailableBankLinkBridge` for the pinned native version, and
/// `DiditBankLinkBridge` (the hand-off into `DiditSdk.shared.presentBankLink`,
/// `resumeBankLink` and `handleBankLinkReturn`) once the native version that
/// carries Bank Link is pinned and the build defines `DIDIT_BANK_LINK`.
protocol BankLinkBridging: AnyObject {
    /// Opens a link. `false` when this native SDK cannot present one, in which
    /// case no callback is ever invoked.
    func present(
        token: String,
        configuration: DiditSdk.Configuration?,
        onEvent: @escaping (BankLinkWire.Event) -> Void,
        onResult: @escaping (BankLinkWire.Outcome) -> Void
    ) -> Bool

    /// Picks up a link whose bank hop outlived the app. `false` when there is
    /// nothing to resume.
    func resume(
        onEvent: @escaping (BankLinkWire.Event) -> Void,
        onResult: @escaping (BankLinkWire.Outcome) -> Void
    ) -> Bool

    /// `true` when the address was a Bank Link return. The address reaches the
    /// native SDK unchanged.
    func handleReturn(_ url: String) -> Bool
}

/// The two messages of the Bank Link channels, in the exact shape Dart reads.
///
/// Result keys: `type` (`success` / `exit`), `linkId`, `connectionId`,
/// `checkId`, `reason`, `step`, `resumed`. Event keys: `name` and `data`, with
/// the native snake_case payload passed through untouched. Ids only: nothing
/// here invents a field, and no token, name or account number has a place.
enum BankLinkWire {
    enum Outcome {
        case success(linkId: String, connectionId: String?, checkId: String?, resumed: Bool)
        case exit(reason: String, step: String?, resumed: Bool)

        var map: [String: Any?] {
            switch self {
            case let .success(linkId, connectionId, checkId, resumed):
                return [
                    "type": "success",
                    "linkId": linkId,
                    "connectionId": connectionId,
                    "checkId": checkId,
                    "resumed": resumed,
                ]
            case let .exit(reason, step, resumed):
                return [
                    "type": "exit",
                    "reason": reason,
                    "step": step,
                    "resumed": resumed,
                ]
            }
        }
    }

    struct Event {
        let name: String
        let payload: [String: Any]

        var map: [String: Any] { ["name": name, "data": payload] }
    }
}

/// The bridge of a native SDK that does not carry Bank Link yet: opening a link
/// answers `false` (Dart reads it as a `failed` exit), there is nothing to
/// resume, and no address is a return.
final class UnavailableBankLinkBridge: BankLinkBridging {
    func present(
        token: String,
        configuration: DiditSdk.Configuration?,
        onEvent: @escaping (BankLinkWire.Event) -> Void,
        onResult: @escaping (BankLinkWire.Outcome) -> Void
    ) -> Bool { false }

    func resume(
        onEvent: @escaping (BankLinkWire.Event) -> Void,
        onResult: @escaping (BankLinkWire.Outcome) -> Void
    ) -> Bool { false }

    func handleReturn(_ url: String) -> Bool { false }
}

/// The one place the pin flips: `DIDIT_BANK_LINK` is defined by the podspec
/// (`SWIFT_ACTIVE_COMPILATION_CONDITIONS`) and `Package.swift`
/// (`swiftSettings: [.define("DIDIT_BANK_LINK")]`) in the change that moves the
/// native dependency to a version carrying Bank Link. Until then the plugin
/// ships the unavailable bridge.
enum BankLinkBridgeFactory {
    static func make() -> BankLinkBridging {
        #if DIDIT_BANK_LINK
        return DiditBankLinkBridge()
        #else
        return UnavailableBankLinkBridge()
        #endif
    }
}
