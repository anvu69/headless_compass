# headless_compass

La bàn **không giao diện** cho iOS. Không widget nào — chỉ một luồng dữ liệu:
hướng, sai số, và nguồn số đo.

> Headless compass for iOS: no widgets, just a typed stream of heading, accuracy
> and source. Magnetic heading needs no permission; true north is requested only
> when you ask for it.

## Ba thứ gói này làm

| Hàm | Việc |
|---|---|
| `isAvailable()` | `CLLocationManager.headingAvailable()` hỏi **lúc chạy**, không suy từ đời máy |
| `watch()` | Luồng `HeadingSample`: độ, sai số, và nguồn (từ bắc hay bắc thật) |
| `requestTrueNorth()` | Xin quyền vị trí **chỉ khi được gọi**, rồi bật bắc thật |

```dart
final compass = HeadingSource();

if (await compass.isAvailable()) {
  compass.watch().listen((s) {
    if (!s.isUsable) return;      // sai số âm: iOS đang nói "đừng tin"
    print('${s.deg}° ±${s.accuracyDeg}° (${s.kind.name})');
  });
}
```

## Hai quy ước ÂM của Apple

Đây là phần dễ sai nhất, nên đặt lên đầu.

- **`headingAccuracy` âm** nghĩa là số đo **không tin được** — không phải lỗi.
  `HeadingSample.isUsable` trả `false` cho mọi mẫu như vậy. Quay mặt số theo nó
  là hiện một con số sai mà không có dấu hiệu nào.
- **`trueHeading` âm** nghĩa là **chưa có vị trí**. Gói rơi về `magneticHeading`
  ngay trong Swift thay vì đẩy số âm sang Dart; đẩy sang thì Dart coi là không
  dùng được, và mặt số đứng im dù từ kế vẫn tốt.

## Không bao giờ ném

Kênh nền tảng hỏng — chạy trên máy ảo, chạy trước khi plugin đăng ký xong, bản
dựng thiếu tệp Swift — đều cho ra `isAvailable() == false` chứ không ném. Ứng
dụng gọi nó không phải bọc `try`, và một màn hình trắng không bao giờ là hậu quả
của việc thiếu từ kế.

## Quyền vị trí

Gói **không** khai `NSLocationWhenInUseUsageDescription`. Câu giải thích quyền
là chuyện của sản phẩm, không phải của thư viện — app dùng gói tự khai lấy.

Từ bắc **không** cần quyền. Chỉ `requestTrueNorth()` mới xin, và chỉ khi được
gọi. Người dùng từ chối thì luồng vẫn chạy, chỉ ở lại từ bắc.

## Chỉ iOS

Không có phần Android. Không phải thiếu sót — gói sinh ra để bọc
`CLLocationManager`, và mọi thứ trong nó là ngữ nghĩa của Apple.

## Vì sao là một gói, không phải vài tệp trong app

Đặt một tệp `.swift` vào `ios/Runner/` của một app Flutter thì nó **chỉ được
biên dịch nếu có trong target Xcode**. Với `project.pbxproj` kiểu cũ, thêm tệp
bằng tay không đưa nó vào target — và **không có lỗi nào nổ**, mã chỉ lặng lẽ
không chạy.

Gói plugin có podspec riêng, nên mọi tệp Swift trong nó đều được biên dịch.

Muốn chắc gói đã được đăng ký thì **đừng tin log**: gói nuốt
`MissingPluginException` và trả `false`, nên "kênh hỏng" và "máy không có từ kế"
trông y hệt nhau. Kiểm ba chỗ tĩnh: `GeneratedPluginRegistrant.m`,
`Podfile.lock`, và `Runner.app/Frameworks/`.
