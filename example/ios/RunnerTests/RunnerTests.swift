import DiditSDK
import Flutter
import UIKit
import XCTest

@testable import didit_sdk

// The native SDK runs every step of the flow, Bank and Location included, and reports a
// single VerificationResult when the flow ends. These tests cover the plugin's side of that
// hand-off: the Dart configuration it passes to the native SDK, the calls it rejects before
// presenting anything, and the map each result shape reaches Dart as.
//
// Run them from Xcode (Runner.xcworkspace, RunnerTests scheme) or with `xcodebuild test`.

class RunnerTests: XCTestCase {

  private let plugin = SdkFlutterPlugin()

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
}
