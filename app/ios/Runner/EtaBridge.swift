import Flutter
import MapKit

/// Bridges Apple's MapKit (real driving-time routing, free, ships with
/// the OS) to Dart over a MethodChannel, for the ad-hoc member ETA
/// feature. Android has no MapKit equivalent — see
/// lib/services/eta_service.dart, which falls back to a straight-line-
/// distance estimate there instead.
final class EtaBridge: NSObject {
  static let channelName = "com.srigautham.waypoint/eta"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let bridge = EtaBridge()
    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "drivingEtaSeconds":
      guard let args = call.arguments as? [String: Any],
            let fromLat = args["fromLat"] as? Double, let fromLng = args["fromLng"] as? Double,
            let toLat = args["toLat"] as? Double, let toLng = args["toLng"] as? Double else {
        result(FlutterError(code: "bad_args", message: "Missing coordinates.", details: nil))
        return
      }

      let source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: fromLat, longitude: fromLng)))
      let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: toLat, longitude: toLng)))
      let request = MKDirections.Request()
      request.source = source
      request.destination = destination
      request.transportType = .automobile

      let directions = MKDirections(request: request)
      directions.calculateETA { response, error in
        // FlutterResult must be invoked on the platform (main) thread.
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "directions_failed", message: error.localizedDescription, details: nil))
            return
          }
          guard let response = response else {
            result(FlutterError(code: "directions_failed", message: "No ETA response.", details: nil))
            return
          }
          result(response.expectedTravelTime)
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
