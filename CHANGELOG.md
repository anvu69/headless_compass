## 0.2.4

* Restart heading updates after changing `headingOrientation`.

  Writing `headingOrientation` while `startUpdatingHeading()` is already
  running makes CoreLocation rebuild its heading computation, and on iOS 26 it
  then stops delivering samples. No error, no callback — the stream just goes
  quiet, exactly when the device is rotated. Calling `startUpdatingHeading()`
  again is a no-op when the stream is healthy, so it costs nothing in the
  common case and recovers the broken one. It runs only on the branch that
  actually changed orientation: once per rotation, not once per sample like
  the layer 0.2.2 had to withdraw.

## 0.2.3

* Revert the per-sample orientation re-check added in 0.2.2. It killed the very
  stream it was meant to protect.

  0.2.2 called the orientation update on *every* heading sample as a redundant
  second layer. That reads `UIApplication.shared.connectedScenes` dozens of
  times a second on the main thread, and whenever the interface orientation
  oscillates near a boundary it writes `headingOrientation` again and again —
  each write makes CoreLocation rebuild its heading computation. On a real iPad
  the compass stopped updating after about ten seconds.

  The actual root cause is still fixed, by the first layer:
  `beginGeneratingDeviceOrientationNotifications()`, without which
  `UIDevice.orientationDidChangeNotification` never fires at all. That is the
  standard, cheap fix and it is enough.

  Lesson kept in the source: a redundant layer that kills what it protects is
  worse than no layer.

## 0.2.2

* Fix heading being wrong by 90 or 180 degrees after the device is rotated.

  The plugin already set `CLLocationManager.headingOrientation` and already
  registered for `UIDevice.orientationDidChangeNotification`. But iOS only
  posts that notification after something calls
  `UIDevice.current.beginGeneratingDeviceOrientationNotifications()`, and
  nothing did — not the host app, not any of its ten iOS plugins, not the
  Flutter 3.44 iOS embedder. So the orientation was applied exactly once, when
  the stream started, and then froze. Rotating the device end-for-end put every
  reading out by 180 degrees, with nothing on screen to say so: this is a
  different frame of reference, not sensor noise, so the error is identical at
  every angle.

  Two layers now, deliberately redundant:

  1. `beginGeneratingDeviceOrientationNotifications()` on listen, and
     `endGeneratingDeviceOrientationNotifications()` on cancel. UIKit
     reference-counts these, so calling them once too often is harmless while
     calling them too rarely fails silently.
  2. Re-check `interfaceOrientation` on every heading sample and reapply only
     when it changed. This takes a completely different route from layer 1, so
     the same class of failure cannot come back if layer 1 breaks again for
     some other reason. It also covers two cases layer 1 does not: the device
     notification can fire *before* the interface has finished rotating, and
     iPadOS 26 window resizing changes the interface orientation without any
     device rotation at all.

  Cost: exactly one stale sample per rotation. With `kCLHeadingFilterNone`
  samples arrive continuously, so that is a few tens of milliseconds.

## 0.2.1

* Set `headingFilter` to `kCLHeadingFilterNone` instead of `0.1` degrees.

  With a filter, CoreLocation stops calling back while the device is still — so
  from Dart, "the device is sitting on a table" and "the channel is dead" look
  exactly the same: no samples. No rule above this layer can tell them apart,
  because the information is already gone here.

  Measured on a real iPad: put the device down and the consuming app went blank
  three seconds later, when its own silence timer fired. Yet the heading of a
  still device is still correct — it does not decay.

  With no filter, iOS delivers every update, so silence means one thing only.
  The cost is more callbacks, and therefore more battery, while the stream is
  running. That has not been measured.

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
