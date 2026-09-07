import 'package:flutter/services.dart';

/// Số đo hướng đến từ đâu.
enum HeadingSourceKind {
  /// Từ bắc — KHÔNG cần quyền vị trí.
  magnetic,

  /// Bắc thật — cần quyền vị trí, và chỉ xin khi người dùng bấm.
  trueNorth,

  /// Không có từ kế, hoặc kênh nền tảng không trả lời.
  unavailable,
}

/// Một lần đọc hướng.
class HeadingSample {
  const HeadingSample({
    required this.deg,
    required this.accuracyDeg,
    required this.kind,
    this.fieldUt,
  });

  final double deg;

  /// Sai số ± tính bằng độ. **Số ÂM nghĩa là không tin được** — đó là quy ước
  /// của `CLHeading.headingAccuracy`, không phải lỗi.
  final double accuracyDeg;

  final HeadingSourceKind kind;

  /// Cường độ từ trường đo được, tính bằng microtesla — độ lớn của vector
  /// `(x, y, z)` mà `CLHeading` trả về.
  ///
  /// `null` khi nền không giao (bản iOS cũ, hoặc mẫu `unavailable`).
  ///
  /// Từ trường Trái Đất nằm trong khoảng **25–65 µT** ở mọi nơi trên mặt đất.
  /// Ra ngoài khoảng ấy nghĩa là có SẮT hoặc NAM CHÂM gần — bao da có nam
  /// châm, chân bàn, cốt thép sàn, và với iPad thì cả dãy nam châm gắn bao và
  /// chỗ hít bút của CHÍNH cái máy.
  ///
  /// Gói này chỉ ĐO và giao con số; nói gì với người dùng là việc của tầng
  /// trên. Cố ý không có ngưỡng nào ở đây: ngưỡng là một quyết định sản phẩm,
  /// và một gói công khai không nên chôn quyết định ấy vào chỗ không ai sửa
  /// được.
  final double? fieldUt;

  /// Có được phép quay mặt số theo mẫu này không.
  ///
  /// Quay theo một mẫu sai số âm là hiện một con số sai mà không có dấu hiệu
  /// nào cho người dùng biết.
  bool get isUsable =>
      kind != HeadingSourceKind.unavailable && accuracyDeg >= 0;
}

/// Cửa vào duy nhất tới từ kế.
///
/// Tự viết kênh thay vì dùng gói: app chỉ chạy iOS, ta cần đúng ba thứ của
/// `CLLocationManager`, và spec §5.7 đòi một ranh giới không gói nào giữ hộ —
/// quyền vị trí chỉ xin khi bấm "Bắc thật".
class HeadingSource {
  static const String methodChannelName = 'headless_compass/method';
  static const String eventChannelName = 'headless_compass/stream';

  static const MethodChannel _method = MethodChannel(methodChannelName);
  static const EventChannel _events = EventChannel(eventChannelName);

  /// Máy này có từ kế không. Hỏi LÚC CHẠY, không suy từ đời máy.
  ///
  /// Kênh hỏng thì trả `false`: chạy trên máy ảo, chạy trước khi plugin đăng ký
  /// xong, hoặc bản dựng thiếu tệp Swift đều rơi vào đây. Ném thì cả tab trắng,
  /// trong khi thứ đúng phải làm là rơi về L9 — vẫn gõ độ được.
  Future<bool> isAvailable() async {
    try {
      final ok = await _method.invokeMethod<bool>('isAvailable');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Xin quyền vị trí rồi bật bắc thật. Trả `false` khi người dùng từ chối.
  ///
  /// Gọi CHỈ KHI người dùng bấm "Bắc thật" — spec §5.7. Từ chối thì rơi về Từ
  /// Bắc, không khoá màn.
  Future<bool> requestTrueNorth() async {
    try {
      final ok = await _method.invokeMethod<bool>('requestTrueNorth');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  Stream<HeadingSample> watch() => _events
      .receiveBroadcastStream()
      .map((e) => parseSample(Map<String, Object?>.from(e as Map)));

  /// Dựng mẫu từ dữ liệu kênh. Công khai để test được mà không cần kênh thật.
  ///
  /// Thiếu trường hoặc `kind` lạ thì về [HeadingSourceKind.unavailable]: dữ
  /// liệu từ tầng nền không phải thứ mình kiểm soát, và ném ở đây thì cả luồng
  /// chết theo một khung hỏng.
  static HeadingSample parseSample(Map<String, Object?> raw) {
    final deg = (raw['deg'] as num?)?.toDouble();
    final acc = (raw['accuracyDeg'] as num?)?.toDouble();
    final kind = switch (raw['kind']) {
      'magnetic' => HeadingSourceKind.magnetic,
      'trueNorth' => HeadingSourceKind.trueNorth,
      _ => HeadingSourceKind.unavailable,
    };

    if (deg == null || acc == null) {
      return const HeadingSample(
          deg: 0, accuracyDeg: -1, kind: HeadingSourceKind.unavailable);
    }
    return HeadingSample(
      deg: deg,
      accuracyDeg: acc,
      kind: kind,
      // Đọc THẬN TRỌNG: nền cũ không giao khoá này, và một bản app ghim thẻ cũ
      // vẫn phải chạy được. Thiếu thì `null`, không phải 0 — 0 là một cường độ
      // CÓ NGHĨA (và là một cường độ bất thường), còn `null` nghĩa là không đo
      // được.
      fieldUt: (raw['fieldUt'] as num?)?.toDouble(),
    );
  }
}
