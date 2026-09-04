## 0.2.0

* Set `CLLocationManager.headingOrientation` from the current interface
  orientation, and keep it updated when the device rotates. Without this every
  reading is off by 90 degrees in a landscape-locked app — the default assumes
  portrait.

## 0.1.1

* Fix podspec metadata: 0.1.0 shipped with the `flutter create` template values
  (`Your Company`, `email@example.com`, `http://example.com`) and a version
  field stuck at `0.0.1`.
* Add a privacy manifest declaring that this package collects nothing.

## 0.1.0

First release.

* `isAvailable()` — runtime check via `CLLocationManager.headingAvailable()`,
  never inferred from the device model.
* `watch()` — stream of `HeadingSample` carrying degrees, accuracy and source
  (magnetic or true north).
* `requestTrueNorth()` — asks for location permission **only when called**.
  Denial keeps the stream running on magnetic heading.
* Never throws. A missing plugin, a simulator, or a device without a
  magnetometer all surface as `isAvailable() == false`.
* `HeadingSample.isUsable` is `false` whenever `headingAccuracy` is negative —
  that is Apple's way of saying the reading cannot be trusted.
* iOS only.
