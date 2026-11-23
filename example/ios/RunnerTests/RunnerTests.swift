import DiditSDK
import Flutter
import UIKit
import XCTest

@testable import didit_sdk

// The native SDK runs every step of the flow, Bank and Location included, and reports a
// single VerificationResult when the flow ends. These tests cover the plugin's side of that
// hand-off: the Dart configuration it passes to the native SDK, the calls it rejects before
// presenting anything, and the map each result shape reaches Dart as. The whole round trip,
// from Dart through the native SDK's own callback and back, is checked by
// example/integration_test/retry_blocked_test.dart (tool/ios_bridge_test.sh).
//
// CI runs them in the iOS example job; CONTRIBUTING.md shows how to run them on a Mac.

class RunnerTests: XCTestCase {

  private var plugin = SdkFlutterPlugin()

  private func reply(to method: String, arguments: Any?) -> Any? {
    var reply: Any?
    let replied = expectation(description: "\(method) replies")
    plugin.handle(FlutterMethodCall(methodName: method, arguments: arguments)) { result in
      reply = result
      replied.fulfill()
    }
    waitForExpectations(timeout: 1)
    return reply
  }

  private func strings(_ map: [String: Any?]) -> [String: String] {
    map.compactMapValues { $0 as? String }
  }

  func testStartVerificationWithoutATokenIsRejected() {
    let error = reply(to: "startVerification", arguments: [String: Any]()) as? FlutterError

    XCTAssertEqual(error?.code, "INVALID_ARGUMENT")
  }

  func testStartVerificationWithWorkflowWithoutAWorkflowIdIsRejected() {
    let error = reply(to: "startVerificationWithWorkflow", arguments: [String: Any]()) as? FlutterError

    XCTAssertEqual(error?.code, "INVALID_ARGUMENT")
  }

  func testUnknownMethodIsNotImplemented() {
    let result = reply(to: "getPlatformVersion", arguments: nil) as? NSObject

    XCTAssertTrue(result === FlutterMethodNotImplemented)
  }

  func testConfigurationKeepsTheDartLanguageAndOptions() {
    let configuration = plugin.parseConfiguration([
      "languageCode": "es",
      "showCloseButton": false,
      "defaultDocumentCamera": "front",
    ])

    XCTAssertEqual(configuration?.languageLocale, .spanish)
    XCTAssertEqual(configuration?.showCloseButton, false)
    XCTAssertEqual(configuration?.defaultDocumentCamera, .front)
  }

  func testCompletedSessionReturnsItsIdAndFinalStatus() {
    let statuses: [(VerificationStatus, String)] = [
      (.approved, "Approved"),
      (.pending, "Pending"),
      (.declined, "Declined"),
    ]
    for (status, rawStatus) in statuses {
      let mapped = SdkFlutterPlugin.mapVerificationResult(
        .completed(session: SessionData(sessionId: "session-1", status: status))
      )

      XCTAssertEqual(strings(mapped), ["type": "completed", "sessionId": "session-1", "status": rawStatus])
    }
  }

  func testCancelledSessionReturnsTheSessionWhenOneExists() {
    let withSession = SdkFlutterPlugin.mapVerificationResult(
      .cancelled(session: SessionData(sessionId: "session-1", status: .pending))
    )
    let withoutSession = SdkFlutterPlugin.mapVerificationResult(.cancelled(session: nil))

    XCTAssertEqual(strings(withSession), ["type": "cancelled", "sessionId": "session-1", "status": "Pending"])
    XCTAssertEqual(strings(withoutSession), ["type": "cancelled"])
  }

  func testFailedSessionReturnsTheErrorTypeAndMessage() {
    let errors: [(VerificationError, String)] = [
      (.sessionExpired, "sessionExpired"),
      (.retryBlocked, "retryBlocked"),
      (.networkError, "networkError"),
      (.cameraAccessDenied, "cameraAccessDenied"),
      (.unknown("Unsupported verification step"), "unknown"),
    ]
    for (error, errorType) in errors {
      let mapped = SdkFlutterPlugin.mapVerificationResult(
        .failed(error: error, session: SessionData(sessionId: "session-1", status: .pending))
      )

      XCTAssertEqual(strings(mapped), [
        "type": "failed",
        "errorType": errorType,
        "errorMessage": error.localizedDescription,
        "sessionId": "session-1",
        "status": "Pending",
      ])
    }
  }

  // MARK: - Bank Link

  // The wrapper adds no flow of its own: the native SDK owns every screen and
  // reports the link's events and its one result. These tests drive the plugin
  // against a fake native module and pin what Dart reads: the exact keys of
  // every result and event, one result per call, and a token or return address
  // that reaches the native SDK unchanged (a resume code keeps its dot).

  private final class FakeBankLinkBridge: BankLinkBridging {
    var presentedTokens: [String] = []
    var presentedConfigurations: [DiditSdk.Configuration?] = []
    var returnAddresses: [String] = []
    var starts = true
    var resumes = false
    var handles = false
    var resumeOutcome: BankLinkWire.Outcome?

    private var onEvent: ((BankLinkWire.Event) -> Void)?
    private var onResult: ((BankLinkWire.Outcome) -> Void)?

    func emit(_ event: BankLinkWire.Event) {
      onEvent?(event)
    }

    func finish(_ outcome: BankLinkWire.Outcome) {
      onResult?(outcome)
    }

    func present(
      token: String,
      configuration: DiditSdk.Configuration?,
      onEvent: @escaping (BankLinkWire.Event) -> Void,
      onResult: @escaping (BankLinkWire.Outcome) -> Void
    ) -> Bool {
      presentedTokens.append(token)
      presentedConfigurations.append(configuration)
      self.onEvent = onEvent
      self.onResult = onResult
      return starts
    }

    func resume(
      onEvent: @escaping (BankLinkWire.Event) -> Void,
      onResult: @escaping (BankLinkWire.Outcome) -> Void
    ) -> Bool {
      self.onEvent = onEvent
      self.onResult = onResult
      if let outcome = resumeOutcome { onResult(outcome) }
      return resumes
    }

    func handleReturn(_ url: String) -> Bool {
      returnAddresses.append(url)
      return handles
    }
  }

  private let bankLinkToken = "blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W"

  private let bankLinkReturn = "https://app.example.com/bank/return"
    + "?didit_resume=rsc_0b9c4f1e6a2d4e8b9f317c5d2e1a8b40"
    + ".7Hq3Zx9Wd2Lm5Tn8Vc1Ks4Pa6Rb0Uv3"

  /// Puts a fake native module behind the plugin every bridge test drives.
  private func fakeBankLink() -> FakeBankLinkBridge {
    let bridge = FakeBankLinkBridge()
    plugin.bankLinkBridge = bridge
    return bridge
  }

  /// Opens a link without waiting for an answer: a presented link answers
  /// only when its flow ends, which is the next event the test drives.
  private func startBankLink(_ arguments: [String: Any]? = nil) {
    plugin.handle(
      FlutterMethodCall(
        methodName: "presentBankLink",
        arguments: arguments ?? ["token": bankLinkToken]
      )
    ) { _ in }
  }

  func testBankLinkForwardsTheTokenAndConfigurationToTheNativeSdk() {
    let bridge = fakeBankLink()

    startBankLink([
      "token": bankLinkToken,
      "options": ["config": ["languageCode": "es"]],
    ] as [String: Any])

    XCTAssertEqual(bridge.presentedTokens, [bankLinkToken])
    let configuration = bridge.presentedConfigurations.first ?? nil
    XCTAssertEqual(configuration?.languageLocale, .spanish)
  }

  func testEveryBankLinkEventReachesTheChannelWithItsNameAndPayloadUntouched() {
    let bridge = fakeBankLink()
    var events: [Any?] = []
    plugin.bankLinkEvents = { events.append($0) }

    startBankLink()
    bridge.emit(BankLinkWire.Event(
      name: "opened",
      payload: ["link_id": "link-1", "mode": "connect", "access": "ongoing"]
    ))
    bridge.emit(BankLinkWire.Event(
      name: "exit",
      payload: ["reason": "closed", "step": "consent", "link_id": "link-1"]
    ))

    let sent = events.compactMap { $0 as? [String: Any] }
    let opened = sent.first?["data"] as? [String: Any]
    XCTAssertEqual(sent.count, 2)
    XCTAssertEqual(sent.first?["name"] as? String, "opened")
    XCTAssertEqual(opened?["link_id"] as? String, "link-1")
    XCTAssertEqual(opened?["mode"] as? String, "connect")
    XCTAssertEqual(opened?["access"] as? String, "ongoing")
    XCTAssertEqual(sent.last?["name"] as? String, "exit")
  }

  func testBankLinkSuccessSettlesDartWithItsIdsAndResumedFlag() {
    let bridge = fakeBankLink()
    var answer: Any?

    plugin.handle(
      FlutterMethodCall(methodName: "presentBankLink", arguments: ["token": bankLinkToken])
    ) { answer = $0 }
    bridge.finish(.success(
      linkId: "link-1",
      connectionId: "connection-1",
      checkId: "check-1",
      resumed: true
    ))

    let map = answer as? [String: Any?]
    XCTAssertEqual(map?["type"] as? String, "success")
    XCTAssertEqual(map?["linkId"] as? String, "link-1")
    XCTAssertEqual(map?["connectionId"] as? String, "connection-1")
    XCTAssertEqual(map?["checkId"] as? String, "check-1")
    XCTAssertEqual(map?["resumed"] as? Bool, true)
  }

  func testEveryBankLinkExitReasonReachesDartAsItsWireName() {
    for reason in ["closed", "cancelled", "bank_unavailable", "expired", "failed"] {
      plugin = SdkFlutterPlugin()
      let bridge = fakeBankLink()
      var answer: Any?

      plugin.handle(
        FlutterMethodCall(methodName: "presentBankLink", arguments: ["token": bankLinkToken])
      ) { answer = $0 }
      bridge.finish(.exit(reason: reason, step: "bank_hop", resumed: false))

      let map = answer as? [String: Any?]
      XCTAssertEqual(map?["type"] as? String, "exit", reason)
      XCTAssertEqual(map?["reason"] as? String, reason)
      XCTAssertEqual(map?["step"] as? String, "bank_hop")
    }
  }

  func testASecondBankLinkResultIsDroppedSoDartSettlesOnce() {
    let bridge = fakeBankLink()
    var answers: [Any?] = []

    plugin.handle(
      FlutterMethodCall(methodName: "presentBankLink", arguments: ["token": bankLinkToken])
    ) { answers.append($0) }
    bridge.finish(.exit(reason: "closed", step: "consent", resumed: false))
    bridge.finish(.exit(reason: "failed", step: nil, resumed: false))

    XCTAssertEqual(answers.count, 1)
  }

  func testASecondBankLinkWhileOneIsOpenFailsWithoutReachingTheNativeSdk() {
    let bridge = fakeBankLink()

    startBankLink()
    let second = reply(
      to: "presentBankLink",
      arguments: ["token": bankLinkToken]
    ) as? [String: Any?]

    XCTAssertEqual(bridge.presentedTokens.count, 1)
    XCTAssertEqual(second?["type"] as? String, "exit")
    XCTAssertEqual(second?["reason"] as? String, "failed")
  }

  func testResumeAnswersNilWhenTheNativeSdkHasNothingPending() {
    _ = fakeBankLink()

    let answer = reply(to: "resumeBankLink", arguments: nil)

    XCTAssertNil(answer)
  }

  func testResumeAnswersAReplayedResultWithItsResumedFlag() {
    let bridge = fakeBankLink()
    bridge.resumes = true
    bridge.resumeOutcome = .success(
      linkId: "link-1",
      connectionId: nil,
      checkId: nil,
      resumed: true
    )

    let answer = reply(to: "resumeBankLink", arguments: nil) as? [String: Any?]

    XCTAssertEqual(answer?["type"] as? String, "success")
    XCTAssertEqual(answer?["linkId"] as? String, "link-1")
    XCTAssertEqual(answer?["resumed"] as? Bool, true)
  }

  func testResumeWhileALinkIsOpenAnswersNilWithoutReachingTheNativeSdk() {
    let bridge = fakeBankLink()
    var presented: [Any?] = []
    plugin.handle(
      FlutterMethodCall(methodName: "presentBankLink", arguments: ["token": bankLinkToken])
    ) { presented.append($0) }
    bridge.resumes = true

    var resumed: [Any?] = []
    plugin.handle(FlutterMethodCall(methodName: "resumeBankLink", arguments: nil)) {
      resumed.append($0)
    }
    bridge.finish(.exit(reason: "closed", step: "consent", resumed: false))

    // The resume did not take the open link's callbacks: the presenting call
    // gets its result, and the resume answered nil once.
    XCTAssertEqual(resumed.count, 1)
    XCTAssertNil(resumed.first ?? nil)
    XCTAssertEqual(presented.count, 1)
    XCTAssertEqual((presented.first as? [String: Any?])?["reason"] as? String, "closed")
  }

  func testAResumeThatFoundNothingIsNotAnsweredAgainByALateCallback() {
    let bridge = fakeBankLink()
    var answers: [Any?] = []

    plugin.handle(FlutterMethodCall(methodName: "resumeBankLink", arguments: nil)) {
      answers.append($0)
    }
    bridge.finish(.exit(reason: "failed", step: nil, resumed: true))

    XCTAssertEqual(answers.count, 1)
    XCTAssertNil(answers.first ?? nil)
  }

  func testABankLinkReturnAddressReachesTheNativeHandlerUnchanged() {
    let bridge = fakeBankLink()
    bridge.handles = true

    let answer = reply(
      to: "handleBankLinkReturn",
      arguments: ["url": bankLinkReturn]
    )

    XCTAssertEqual(bridge.returnAddresses, [bankLinkReturn])
    XCTAssertEqual(answer as? Bool, true)
  }

  func testAnAddressThatIsNotABankLinkReturnIsReportedAsSuch() {
    _ = fakeBankLink()

    let answer = reply(
      to: "handleBankLinkReturn",
      arguments: ["url": "https://app.example.com/other"]
    )

    XCTAssertEqual(answer as? Bool, false)
  }

  func testAResumeCodeWithItsDotReachesTheNativeHandlerUnchanged() {
    let bridge = fakeBankLink()
    bridge.handles = true

    _ = reply(to: "handleBankLinkReturn", arguments: ["url": bankLinkReturn])

    XCTAssertEqual(bridge.returnAddresses.first, bankLinkReturn)
    XCTAssertTrue(bridge.returnAddresses.first?.contains("rsc_") ?? false)
    XCTAssertTrue(bridge.returnAddresses.first?.contains(".7Hq3") ?? false)
  }
}
