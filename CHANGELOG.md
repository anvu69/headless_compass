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
