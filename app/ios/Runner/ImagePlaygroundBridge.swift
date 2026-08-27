import Flutter
import UIKit

#if canImport(ImagePlayground)
import ImagePlayground
#endif

/// Bridges Apple's Image Playground (iOS 18.1+, Apple-Intelligence-capable
/// devices only) to Dart over a MethodChannel, since Flutter has no plugin
/// for it. See lib/services/cover_generation_service.dart for the Dart side.
@available(iOS 18.1, *)
final class ImagePlaygroundBridge: NSObject {
  static let channelName = "com.waypoint.waypoint/image_playground"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let bridge = ImagePlaygroundBridge()
    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }
  }

  private var pendingResult: FlutterResult?

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      #if canImport(ImagePlayground)
      result(ImagePlaygroundViewController.isAvailable)
      #else
      result(false)
      #endif
    case "generate":
      #if canImport(ImagePlayground)
      guard ImagePlaygroundViewController.isAvailable else {
        result(FlutterError(code: "unavailable", message: "Image Playground isn't available on this device.", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any], let concept = args["concept"] as? String, !concept.isEmpty else {
        result(FlutterError(code: "bad_args", message: "Missing 'concept'.", details: nil))
        return
      }
      guard let presenter = Self.topViewController() else {
        result(FlutterError(code: "no_view_controller", message: "No view controller to present from.", details: nil))
        return
      }
      pendingResult = result

      let playgroundVC = ImagePlaygroundViewController()
      playgroundVC.concepts = [.text(concept)]
      playgroundVC.delegate = self
      presenter.present(playgroundVC, animated: true)
      #else
      result(FlutterError(code: "unavailable", message: "Image Playground isn't available on this device.", details: nil))
      #endif
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
    let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}

#if canImport(ImagePlayground)
@available(iOS 18.1, *)
extension ImagePlaygroundBridge: ImagePlaygroundViewController.Delegate {
  func imagePlaygroundViewController(
    _ imagePlaygroundViewController: ImagePlaygroundViewController,
    didCreateImageAt imageURL: URL
  ) {
    imagePlaygroundViewController.dismiss(animated: true) {
      do {
        let data = try Data(contentsOf: imageURL)
        self.pendingResult?(FlutterStandardTypedData(bytes: data))
      } catch {
        self.pendingResult?(FlutterError(code: "read_failed", message: error.localizedDescription, details: nil))
      }
      self.pendingResult = nil
    }
  }

  func imagePlaygroundViewControllerDidCancel(_ imagePlaygroundViewController: ImagePlaygroundViewController) {
    imagePlaygroundViewController.dismiss(animated: true) {
      self.pendingResult?(nil)
      self.pendingResult = nil
    }
  }
}
#endif
