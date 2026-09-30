# headless_compass

A headless compass for iOS. No widgets — just a typed stream of heading,
accuracy, and where the number came from.

Every other Flutter compass package ships a dial. This one ships the data and
lets you draw whatever you want.

## Install

```yaml
dependencies:
  headless_compass: ^0.1.0
```

iOS only. There is no Android implementation, and that is deliberate — this
package wraps `CLLocationManager`, and everything in it is Apple's semantics.

## Use

```dart
final compass = HeadingSource();

if (await compass.isAvailable()) {
  compass.watch().listen((sample) {
    if (!sample.isUsable) return;   // Apple says: do not trust this reading
    print('${sample.deg}° ±${sample.accuracyDeg}° (${sample.kind.name})');
  });
}
```

| Call | What it does |
|---|---|
| `isAvailable()` | `CLLocationManager.headingAvailable()`, asked **at runtime** |
| `watch()` | Stream of `HeadingSample`: degrees, accuracy, source |
| `CameraAttitudeSource().watch()` | Raw attitude matrix (xMagneticNorthZVertical) with calibration level |

## Two negative-number conventions that bite

This is the part that is easy to get wrong, so it goes first.

**A negative `headingAccuracy` means the reading cannot be trusted.** It is not
an error code you can ignore — it is iOS telling you the magnetometer is
confused. `HeadingSample.isUsable` returns `false` for those samples. Rotating a
dial to an untrusted number shows the user a wrong value with no sign that it is
wrong.

## It never throws

A missing plugin registration, a simulator, a device with no magnetometer — all
of them surface as `isAvailable() == false`. You do not need a `try` around any
call in this package, and a blank screen is never the consequence of a missing
sensor.

The trade-off: **you cannot tell "no magnetometer" apart from "plugin not
registered" at runtime.** If you need to prove the plugin is wired up, check
three static places instead of the logs:

- `ios/Runner/GeneratedPluginRegistrant.m` for `HeadlessCompassPlugin`
- `ios/Podfile.lock` for `headless_compass`
- `YourApp.app/Frameworks/` for `headless_compass.framework`

## No permissions at all

Magnetic heading needs no permission, and this package asks for none. It does
not reference `requestWhenInUseAuthorization` anywhere, so linking it does not
make App Store Connect demand `NSLocationWhenInUseUsageDescription`.

That is why true north is gone since 0.3.0. Apple's upload scanner reads the
compiled binary, not your call graph: a permission request sitting in a branch
you never call still earns ITMS-90683 ("Missing purpose string in Info.plist").
If you need true north, read `CLHeading.trueHeading` from your own
`CLLocationManager` after your app asks for location itself.

## Why a package and not a few files in your app

Dropping a `.swift` file into `ios/Runner/` only compiles it **if it is in the
Xcode target**. With a classic `project.pbxproj`, adding the file by hand does
not add it to the target — and nothing fails loudly. The code is simply never
built.

A plugin package has its own podspec, so every Swift file in it is compiled.
That is the whole reason this exists as a package.

## License

MIT.
