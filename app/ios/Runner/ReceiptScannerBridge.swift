import Flutter
import UIKit
import Vision

/// Bridges Apple's own Vision framework (on-device text recognition,
/// iOS 13+, ships with the OS — no CocoaPods/third-party binary) to Dart
/// over a MethodChannel. Chosen over Google's ML Kit Flutter plugin
/// because its iOS pods ship no arm64 simulator slice, which this
/// environment's simulator runtime (iOS 26+, arm64-only, no x86_64
/// fallback) can't work around at all. See
/// lib/services/receipt_scanner_service.dart for the Dart side, which
/// does the amount-parsing — this bridge only returns raw recognized
/// text lines.
final class ReceiptScannerBridge: NSObject {
  static let channelName = "com.srigautham.waypoint/receipt_scanner"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let bridge = ReceiptScannerBridge()
    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "recognizeText":
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
        result(FlutterError(code: "bad_args", message: "Missing 'path'.", details: nil))
        return
      }
      guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
        result(FlutterError(code: "bad_image", message: "Couldn't load image at path.", details: nil))
        return
      }

      let request = VNRecognizeTextRequest { request, error in
        // FlutterResult must be invoked on the platform (main) thread —
        // this completion handler runs on the background queue perform()
        // was dispatched to.
        if let error = error {
          DispatchQueue.main.async {
            result(FlutterError(code: "recognition_failed", message: error.localizedDescription, details: nil))
          }
          return
        }
        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        DispatchQueue.main.async {
          result(lines.joined(separator: "\n"))
        }
      }
      request.recognitionLevel = .accurate

      let orientation = CGImagePropertyOrientation(image.imageOrientation)
      let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try handler.perform([request])
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "recognition_failed", message: error.localizedDescription, details: nil))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private extension CGImagePropertyOrientation {
  init(_ uiOrientation: UIImage.Orientation) {
    switch uiOrientation {
    case .up: self = .up
    case .upMirrored: self = .upMirrored
    case .down: self = .down
    case .downMirrored: self = .downMirrored
    case .left: self = .left
    case .leftMirrored: self = .leftMirrored
    case .right: self = .right
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}
