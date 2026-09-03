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
| `requestTrueNorth()` | Asks for location permission **only when called** |

## Two negative-number conventions that bite

This is the part that is easy to get wrong, so it goes first.

**A negative `headingAccuracy` means the reading cannot be trusted.** It is not
an error code you can ignore — it is iOS telling you the magnetometer is
confused. `HeadingSample.isUsable` returns `false` for those samples. Rotating a
dial to an untrusted number shows the user a wrong value with no sign that it is
wrong.

**A negative `trueHeading` means there is no location fix yet.** This package
falls back to `magneticHeading` inside Swift rather than passing the negative
number to Dart. Passing it through would mark the sample unusable, and the dial
would freeze while the magnetometer was working perfectly.

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

## Location permission

This package does **not** declare `NSLocationWhenInUseUsageDescription`. The
wording of a permission prompt belongs to your product, not to a library. Add it
to your own `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used only to compute true north.</string>
```

Magnetic heading needs no permission at all. Only `requestTrueNorth()` asks, and
only when you call it. If the user declines, the stream keeps running on
magnetic heading — declining is not a dead end.

## Why a package and not a few files in your app

Dropping a `.swift` file into `ios/Runner/` only compiles it **if it is in the
Xcode target**. With a classic `project.pbxproj`, adding the file by hand does
not add it to the target — and nothing fails loudly. The code is simply never
built.

A plugin package has its own podspec, so every Swift file in it is compiled.
That is the whole reason this exists as a package.

## License

MIT.
