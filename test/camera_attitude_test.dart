import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headless_compass/headless_compass.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const m = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9];

  group('CameraAttitudeSource.parseSample', () {
    test('mẫu tư thế đầy đủ', () {
      final s = CameraAttitudeSource.parseSample({
        'kind': 'attitude',
        'm': m,
        'cal': 1,
        'fieldUt': 47.5,
      });
      expect(s.isAvailable, isTrue);
      expect(s.rotation, m);
      expect(s.calibration, MagneticCalibration.medium);
      expect(s.fieldUt, 47.5);
    });

    test('bốn mức hiệu chuẩn của CoreMotion', () {
      for (final (raw, mong) in [
        (-1, MagneticCalibration.uncalibrated),
        (0, MagneticCalibration.low),
        (1, MagneticCalibration.medium),
        (2, MagneticCalibration.high),
      ]) {
        final s = CameraAttitudeSource.parseSample(
          {'kind': 'attitude', 'm': m, 'cal': raw},
        );
        expect(s.calibration, mong, reason: 'cal=$raw');
      }
    });

    // Mức lạ KHÔNG được đọc thành "tốt": đoán sai theo chiều ấy là tắt phiếu
    // nhắc hiệu chuẩn đúng lúc từ kế đang hỏng.
    test('mức hiệu chuẩn lạ hoặc thiếu thì về uncalibrated', () {
      for (final raw in [null, 7, 'x']) {
        final s = CameraAttitudeSource.parseSample(
          {'kind': 'attitude', 'm': m, 'cal': raw},
        );
        expect(s.calibration, MagneticCalibration.uncalibrated);
      }
    });

    test('kind unavailable, thiếu ma trận, ma trận sai cỡ, số không hữu hạn', () {
      for (final raw in <Map<String, Object?>>[
        {'kind': 'unavailable'},
        {'kind': 'attitude'},
        {'kind': 'attitude', 'm': [1.0, 2.0]},
        {'kind': 'attitude', 'm': [...m.take(8), double.nan]},
        {'kind': 'attitude', 'm': [...m.take(8), 'x']},
      ]) {
        final s = CameraAttitudeSource.parseSample(raw);
        expect(s.isAvailable, isFalse, reason: '$raw');
        expect(s.calibration, MagneticCalibration.unavailable);
      }
    });
  });

  test('watch() không ném khi thiếu plugin', () async {
    final loi = <Object>[];
    final sub = CameraAttitudeSource().watch().listen((_) {}, onError: loi.add);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(loi, isEmpty);
  });

  test('tên kênh cố định', () {
    expect(CameraAttitudeSource.eventChannelName, 'headless_compass/attitude');
    expect(const EventChannel(CameraAttitudeSource.eventChannelName).name,
        'headless_compass/attitude');
  });
}
