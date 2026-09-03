# lobanar_heading

Đọc hướng la bàn trên iOS, gói `CLLocationManager` heading thành hai kênh Flutter.

Dùng bởi **Lỗ Ban AR** (`anvu69/lobanar_app`).

## Vì sao gói này tồn tại

Không phải để dùng lại ở nhiều app — nó tồn tại vì một ràng buộc rất cụ thể của
Xcode.

`project.pbxproj` của app chưa dùng nhóm đồng bộ theo thư mục, nên một tệp
`.swift` mới đặt vào `ios/Runner/` **sẽ không vào target mà cũng không có lỗi
nào nổ** — nó chỉ lặng lẽ không được biên dịch. Trước khi tách, mã Swift phải
nằm chung tệp với `AppDelegate` chỉ để chắc chắn nó được dịch.

Gói plugin có **podspec riêng**, nên mọi tệp Swift trong nó đều được biên dịch.
Tách gói gỡ đúng cái ràng buộc đó.

## Ba thứ gói này làm

| Hàm | Việc |
|---|---|
| `isAvailable()` | `CLLocationManager.headingAvailable()` hỏi **lúc chạy**, không suy từ đời máy |
| `watch()` | Luồng `HeadingSample`: độ, sai số, và nguồn (từ bắc hay bắc thật) |
| `requestTrueNorth()` | Xin quyền vị trí **chỉ khi được gọi**, rồi bật bắc thật |

## Hai quy ước ÂM của Apple, cả hai đều lặng lẽ

Đây là phần dễ sai nhất, nên ghi lên đầu:

- **`headingAccuracy` âm** nghĩa là số đo **không tin được** — không phải lỗi.
  `HeadingSample.isUsable` trả `false` cho mọi mẫu như vậy. Quay mặt số theo nó
  là hiện một con số sai mà không có dấu hiệu nào.
- **`trueHeading` âm** nghĩa là **chưa có vị trí**. Gói rơi về `magneticHeading`
  ngay trong Swift thay vì đẩy số âm sang Dart; đẩy sang thì Dart coi là không
  dùng được, và mặt số đứng im dù từ kế vẫn tốt.

## Quyền vị trí

Gói **không** khai `NSLocationWhenInUseUsageDescription`. Câu giải thích quyền
là chuyện của sản phẩm, không phải của thư viện — app dùng gói phải tự khai.

Từ bắc **không** cần quyền. Chỉ `requestTrueNorth()` mới xin, và chỉ khi được
gọi.

## Chỉ iOS

Không có phần Android. Không phải thiếu sót — app dùng nó chỉ chạy iOS.
