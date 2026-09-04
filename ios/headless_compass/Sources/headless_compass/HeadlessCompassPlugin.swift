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
public class HeadlessCompassPlugin: NSObject, FlutterPlugin {
  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?

  /// Đã được người dùng cho phép dùng bắc thật chưa.
  ///
  /// Từ bắc KHÔNG cần quyền vị trí; chỉ `trueHeading` mới cần. Giữ cờ riêng để
  /// không bao giờ đọc `trueHeading` khi chưa xin.
  private var wantsTrueNorth = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = HeadlessCompassPlugin()

    let method = FlutterMethodChannel(
      name: "headless_compass/method", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: method)

    let events = FlutterEventChannel(
      name: "headless_compass/stream", binaryMessenger: registrar.messenger())
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

extension HeadlessCompassPlugin: FlutterStreamHandler {
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
    capNhatHuongMay()

    // Xoay máy thì phải đặt lại. Không nghe thông báo này thì app khoá ngang
    // vẫn đúng, nhưng app cho xoay sẽ sai đúng 90° ngay khi người dùng xoay.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(huongMayDoi),
      name: UIDevice.orientationDidChangeNotification,
      object: nil)

    manager.startUpdatingHeading()
    return nil
  }

  public func onCancel(withArguments _: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(
      self, name: UIDevice.orientationDidChangeNotification, object: nil)
    manager.stopUpdatingHeading()
    sink = nil
    return nil
  }
}

extension HeadlessCompassPlugin {
  @objc func huongMayDoi() { capNhatHuongMay() }

  /// Cho `CLLocationManager` biết cạnh nào của máy đang là cạnh TRÊN của giao
  /// diện.
  ///
  /// Không đặt thì nó mặc định coi máy đang cầm DỌC, và mọi số đọc lệch đúng
  /// 90° trên một app khoá nằm ngang. Đây không phải sai số cảm biến — nó là
  /// một hệ quy chiếu khác, và nó lệch y hệt nhau ở mọi góc.
  ///
  /// **Ánh xạ bị ĐẢO, và đó là chỗ dễ sai nhất:** `UIInterfaceOrientation`
  /// `.landscapeLeft` nghĩa là NÚT HOME nằm bên trái, tức máy đã xoay sang
  /// PHẢI — nên nó tương ứng `CLDeviceOrientation.landscapeRight`. Đặt thẳng
  /// tên sang tên là sai 180°, và 180° thì trông "rõ ràng sai" nên may là dễ
  /// bắt; đặt thẳng ở bản dọc thì lại đúng, nên lỗi chỉ nổ ở bản ngang.
  func capNhatHuongMay() {
    let ui: UIInterfaceOrientation
    if #available(iOS 13.0, *) {
      ui = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.interfaceOrientation ?? .portrait
    } else {
      ui = UIApplication.shared.statusBarOrientation
    }

    switch ui {
    case .portraitUpsideDown: manager.headingOrientation = .portraitUpsideDown
    case .landscapeLeft: manager.headingOrientation = .landscapeRight
    case .landscapeRight: manager.headingOrientation = .landscapeLeft
    default: manager.headingOrientation = .portrait
    }
  }
}

extension HeadlessCompassPlugin: CLLocationManagerDelegate {
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
