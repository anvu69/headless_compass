import CoreLocation
import Flutter
import UIKit

/// Gói `CLLocationManager` heading thành hai kênh cho tầng Dart.
///
/// Tách khỏi app thành gói riêng vì một lý do rất cụ thể: `project.pbxproj` của
/// app chưa dùng nhóm đồng bộ theo thư mục, nên một tệp `.swift` mới đặt vào
/// `ios/Runner/` sẽ KHÔNG vào target mà cũng không có lỗi nào nổ — nó chỉ lặng
/// lẽ không được biên dịch. Gói plugin có podspec riêng, nên mọi tệp Swift
/// trong nó đều được biên dịch.
///
/// Theo `FlutterPlugin` để Flutter tự đăng ký qua `GeneratedPluginRegistrant`.
/// App không phải gọi tay, và đó chính là chỗ dễ quên khi dựng engine mới.
public class LobanarHeadingPlugin: NSObject, FlutterPlugin {
  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?

  /// Đã được người dùng cho phép dùng bắc thật chưa.
  ///
  /// Từ bắc KHÔNG cần quyền vị trí; chỉ `trueHeading` mới cần. Giữ cờ riêng để
  /// không bao giờ đọc `trueHeading` khi chưa xin.
  private var wantsTrueNorth = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = LobanarHeadingPlugin()

    let method = FlutterMethodChannel(
      name: "lobanar/heading", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: method)

    let events = FlutterEventChannel(
      name: "lobanar/heading/stream", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      // Hỏi LÚC CHẠY, không suy từ đời máy: iPad Air M3 bản WiFi có từ kế.
      result(CLLocationManager.headingAvailable())
    case "requestTrueNorth":
      requestTrueNorth(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestTrueNorth(result: @escaping FlutterResult) {
    guard CLLocationManager.headingAvailable() else {
      result(false)
      return
    }
    wantsTrueNorth = true
    manager.requestWhenInUseAuthorization()

    // Rẽ nhánh theo phiên bản thay vì nâng deployment target: dạng thuộc tính
    // của `authorizationStatus` chỉ có từ iOS 14, mà app còn nhắm 13.0. Nâng
    // target chỉ vì một dòng là cắt mất máy cũ để đổi lấy một dòng ngắn hơn.
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    result(status == .authorizedWhenInUse || status == .authorizedAlways)
  }
}

extension LobanarHeadingPlugin: FlutterStreamHandler {
  public func onListen(
    withArguments _: Any?, eventSink: @escaping FlutterEventSink
  ) -> FlutterError? {
    guard CLLocationManager.headingAvailable() else {
      eventSink(["deg": 0.0, "accuracyDeg": -1.0, "kind": "unavailable"])
      return nil
    }
    sink = eventSink
    manager.delegate = self
    manager.headingFilter = 0.1
    manager.startUpdatingHeading()
    return nil
  }

  public func onCancel(withArguments _: Any?) -> FlutterError? {
    manager.stopUpdatingHeading()
    sink = nil
    return nil
  }
}

extension LobanarHeadingPlugin: CLLocationManagerDelegate {
  public func locationManager(
    _: CLLocationManager, didUpdateHeading newHeading: CLHeading
  ) {
    // trueHeading ÂM nghĩa là chưa có vị trí. Rơi về magneticHeading thay vì
    // đẩy một số âm sang Dart — Dart coi mọi số âm là không tin được, và mặt số
    // sẽ đứng im dù từ kế vẫn tốt.
    let dungBacThat = wantsTrueNorth && newHeading.trueHeading >= 0
    sink?([
      "deg": dungBacThat ? newHeading.trueHeading : newHeading.magneticHeading,
      "accuracyDeg": newHeading.headingAccuracy,
      "kind": dungBacThat ? "trueNorth" : "magnetic",
    ])
  }

  /// Để iOS hiện HUD hiệu chuẩn hình số tám khi cần.
  public func locationManagerShouldDisplayHeadingCalibration(_: CLLocationManager)
    -> Bool
  {
    true
  }
}
