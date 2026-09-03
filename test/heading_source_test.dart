import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lobanar_heading/lobanar_heading.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel(HeadingSource.methodChannelName);
  final binding = TestDefaultBinaryMessengerBinding.instance;

  void traLoi(Map<String, Object?> ketQua) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      method,
      (call) async => ketQua[call.method],
    );
  }

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(method, null);
  });

  group('có từ kế hay không', () {
    test('máy có từ kế', () async {
      traLoi({'isAvailable': true});

      expect(await HeadingSource().isAvailable(), isTrue);
    });

    test('máy không có từ kế', () async {
      traLoi({'isAvailable': false});

      expect(await HeadingSource().isAvailable(), isFalse);
    });

    // Kênh hỏng là chuyện có thật: chạy trên máy ảo, chạy trước khi plugin đăng
    // ký xong, hoặc bản dựng thiếu tệp Swift. Ném ở đây thì cả tab trắng, mà
    // thứ đúng phải làm là rơi về L9 — vẫn gõ độ được.
    test('kênh hỏng thì coi như KHÔNG có từ kế, không ném', () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        method,
        (call) async => throw MissingPluginException('không có kênh'),
      );

      expect(await HeadingSource().isAvailable(), isFalse);
    });

    test('xin bắc thật mà kênh hỏng thì trả false, không ném', () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        method,
        (call) async => throw MissingPluginException('không có kênh'),
      );

      expect(await HeadingSource().requestTrueNorth(), isFalse);
    });
  });

  group('HeadingSample', () {
    test('mẫu từ bắc dùng được', () {
      const s =
          HeadingSample(deg: 32, accuracyDeg: 2, kind: HeadingSourceKind.magnetic);

      expect(s.isUsable, isTrue);
    });

    test('mẫu bắc thật dùng được', () {
      const s = HeadingSample(
          deg: 32, accuracyDeg: 2, kind: HeadingSourceKind.trueNorth);

      expect(s.isUsable, isTrue);
    });

    // iOS trả headingAccuracy ÂM khi số đo không tin được. Đó là quy ước của
    // Apple, không phải lỗi — và nếu ta vẫn quay mặt số theo nó thì người dùng
    // đọc một con số sai mà không có dấu hiệu nào.
    test('sai số âm nghĩa là KHÔNG dùng được', () {
      const s = HeadingSample(
          deg: 32, accuracyDeg: -1, kind: HeadingSourceKind.magnetic);

      expect(s.isUsable, isFalse);
    });

    test('nguồn unavailable thì không dùng được', () {
      const s = HeadingSample(
          deg: 0, accuracyDeg: 0, kind: HeadingSourceKind.unavailable);

      expect(s.isUsable, isFalse);
    });
  });

  group('đọc mẫu từ kênh sự kiện', () {
    test('dựng mẫu đủ ba trường', () {
      final s = HeadingSource.parseSample({
        'deg': 32.5,
        'accuracyDeg': 2.0,
        'kind': 'magnetic',
      });

      expect(s.deg, 32.5);
      expect(s.accuracyDeg, 2.0);
      expect(s.kind, HeadingSourceKind.magnetic);
    });

    test('kind lạ thì về unavailable chứ không ném', () {
      final s = HeadingSource.parseSample({
        'deg': 32.5,
        'accuracyDeg': 2.0,
        'kind': 'thứ-gì-đó-mới',
      });

      expect(s.kind, HeadingSourceKind.unavailable);
    });

    test('thiếu trường thì về mẫu không dùng được', () {
      final s = HeadingSource.parseSample({'deg': 32.5});

      expect(s.isUsable, isFalse);
    });
  });
}
