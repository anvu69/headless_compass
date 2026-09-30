import CoreMotion
import Flutter

/// Tư thế máy từ `CMDeviceMotion`, hệ quy chiếu `xMagneticNorthZVertical`.
///
/// Gửi ma trận THÔ, không tính phương vị — xem `CameraAttitudeSample` bên Dart.
/// Không xin quyền nào: `CMDeviceMotion` không cần quyền, và hệ quy chiếu từ
/// bắc chỉ đọc từ kế.
final class AttitudeStreamHandler: NSObject, FlutterStreamHandler {
  private let motion = CMMotionManager()

  func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    guard motion.isDeviceMotionAvailable,
      CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical)
    else {
      events(["kind": "unavailable"])
      return nil
    }
    motion.deviceMotionUpdateInterval = 1.0 / 60.0
    motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { m, _ in
      guard let m else { return }
      let r = m.attitude.rotationMatrix
      let f = m.magneticField.field
      let ut = (f.x * f.x + f.y * f.y + f.z * f.z).squareRoot()
      events([
        "kind": "attitude",
        "m": [r.m11, r.m12, r.m13, r.m21, r.m22, r.m23, r.m31, r.m32, r.m33],
        "cal": Int(m.magneticField.accuracy.rawValue),
        "fieldUt": ut,
      ])
    }
    return nil
  }

  func onCancel(withArguments _: Any?) -> FlutterError? {
    motion.stopDeviceMotionUpdates()
    return nil
  }
}
