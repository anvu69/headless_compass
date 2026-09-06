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

  /// Hướng giao diện đã áp vào `manager.headingOrientation` lần gần nhất.
  ///
  /// Có trường này thì lớp phòng vệ ở [locationManager(_:didUpdateHeading:)]
  /// chỉ ghi khi thật sự đổi, thay vì gán lại mỗi mẫu đo.
  private var appliedOrientation: UIInterfaceOrientation?

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
    // KHÔNG lọc theo độ. `headingFilter = 0.1` nghĩa là máy NẰM YÊN thì
    // CoreLocation không gọi lại — và từ phía Dart, "máy nằm yên" với "kênh
    // chết" cho ra CÙNG MỘT THỨ: không có mẫu. Không luật nào ở tầng trên phân
    // biệt được hai chuyện ấy, vì thông tin đã mất ở ngay đây.
    //
    // Đo trên iPad thật: đặt máy xuống bàn thì đúng 3 giây sau app câm hết, vì
    // đồng hồ im lặng của nó bật. Mà hướng của một cái máy nằm yên VẪN ĐÚNG —
    // nó không hỏng theo thời gian.
    //
    // `kCLHeadingFilterNone` bắt iOS giao mọi lần cập nhật. Khi ấy im lặng chỉ
    // còn đúng MỘT nghĩa, và tầng trên khỏi phải đoán.
    manager.headingFilter = kCLHeadingFilterNone
    capNhatHuongMay()

    // BẬT NGUỒN PHÁT. Thiếu dòng này thì `orientationDidChangeNotification`
    // KHÔNG BAO GIỜ nổ, và cả khối đăng ký ngay dưới thành trang trí.
    //
    // Đó đúng là lỗi đã lên máy thật: `capNhatHuongMay()` chạy một lần duy nhất
    // lúc mở tab rồi `headingOrientation` đông cứng ở hướng lúc ấy. Người dùng
    // xoay iPad cho đầu máy sang phải thì mọi số đọc lệch 180°, xoay sang dọc
    // thì lệch 90° — mà không có gì trên mặt số nói ra, vì đây là một HỆ QUY
    // CHIẾU khác chứ không phải nhiễu từ.
    //
    // Quét ba chỗ trước khi kết luận: `ios/` của app, mười plugin iOS của dự
    // án, và engine iOS của Flutter 3.44 — không nơi nào gọi hàm này. Đừng bỏ
    // đi vì tưởng UIKit tự bật; nó có đếm tham chiếu nên gọi thừa là vô hại,
    // còn gọi thiếu thì im lặng.
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()

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
    UIDevice.current.endGeneratingDeviceOrientationNotifications()
    appliedOrientation = nil
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

    guard ui != appliedOrientation else { return }
    appliedOrientation = ui

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
    // LỚP PHÒNG VỆ THỨ HAI, và nó cố ý DƯ so với lớp thông báo ở trên.
    //
    // Lớp trên đã hỏng một lần theo cách im lặng nhất có thể — đăng ký nghe một
    // thông báo không ai phát. Một lớp nữa, đi đường KHÁC HẲN, là thứ làm lớp
    // lỗi ấy không tái diễn dù lớp trên lại hỏng vì lý do khác.
    //
    // Nó cũng đóng hai chỗ lớp trên KHÔNG đóng:
    //
    // - `orientationDidChangeNotification` nổ theo hướng THIẾT BỊ, và nó có thể
    //   nổ TRƯỚC khi giao diện kịp xoay — đọc `interfaceOrientation` lúc ấy ra
    //   giá trị CŨ, tức đặt lại mà vẫn sai;
    // - cảnh cửa sổ đổi cỡ của iPadOS 26, nơi giao diện đổi mà hướng thiết bị
    //   thì không.
    //
    // Giá phải trả là ĐÚNG MỘT mẫu lệch sau mỗi lần xoay: mẫu này vẫn do hệ quy
    // chiếu cũ tính ra. Với `kCLHeadingFilterNone` thì mẫu về liên tục nên một
    // mẫu là vài chục mili giây — mắt không thấy.
    //
    // Đọc `interfaceOrientation` phải ở luồng chính; delegate của
    // `CLLocationManager` gọi lại trên chính luồng đã dựng manager, tức luồng
    // chính, nên chỗ này an toàn. Có `guard` để nếu điều đó thôi đúng thì nó
    // BỎ QUA lần soát chứ không sập.
    if Thread.isMainThread {
      capNhatHuongMay()
    }

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
