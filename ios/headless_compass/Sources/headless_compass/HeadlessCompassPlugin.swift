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

    // ĐÁNH THỨC LẠI sau khi đổi hệ quy chiếu.
    //
    // Người dùng cầm iPad thật: "gặp vấn đề khi xoay màn hình là la bàn đứng
    // im". Đứng im ĐÚNG LÚC XOAY, tức đúng lúc dòng trên vừa chạy — không
    // phải sau vài giây, không phải ngẫu nhiên.
    //
    // Ghi `headingOrientation` giữa lúc `startUpdatingHeading()` đang chạy
    // làm CoreLocation dựng lại phép tính hướng, và trên iOS 26 nó thôi giao
    // mẫu sau đó. Không có lỗi nào nổ, không có thông báo nào — luồng chỉ im.
    //
    // Gọi lại `startUpdatingHeading()` là phép KHÔNG ĐỔI khi luồng còn sống
    // (tài liệu Apple: gọi nhiều lần không sinh thêm luồng), nên nó vô hại ở
    // ca luồng không đứt và cứu được ca luồng đứt. Chỉ chạy ở nhánh ĐÃ ĐỔI
    // hướng — mỗi lần xoay đúng một lần, không phải mỗi mẫu như bản 0.2.2 đã
    // phải rút lại.
    if sink != nil {
      manager.startUpdatingHeading()
    }
  }
}

extension HeadlessCompassPlugin: CLLocationManagerDelegate {
  public func locationManager(
    _: CLLocationManager, didUpdateHeading newHeading: CLHeading
  ) {
    // KHÔNG soát lại hướng ở đây, và đó là một quyết định ĐÃ RÚT LẠI.
    //
    // Bản 0.2.2 gọi `capNhatHuongMay()` ở MỖI mẫu đo, làm "lớp phòng vệ thứ
    // hai" cho lớp thông báo bên trên. Nó đọc `UIApplication.shared
    // .connectedScenes` mấy chục lần mỗi giây trên luồng chính, và khi giao
    // diện dao động quanh một ranh hướng thì nó ghi `manager.headingOrientation`
    // liên tục — mỗi lần ghi là một lần CoreLocation dựng lại phép tính hướng.
    //
    // Người dùng cầm iPad thật báo: "chỉ dùng được khoảng 10 giây rồi la bàn
    // không hoạt động nữa". Lớp phòng vệ giết đúng cái luồng nó sinh ra để bảo
    // vệ.
    //
    // Gốc thật đã được lớp MỘT chữa — bật
    // `beginGeneratingDeviceOrientationNotifications()` để thông báo xoay máy
    // thật sự nổ. Lớp hai là thứ tôi thêm cho chắc mà không đo giá của nó.
    // Một lớp dư làm chết thứ nó bảo vệ thì tệ hơn không có lớp nào.

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
