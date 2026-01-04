# Kiblat 📍

A lightweight Flutter app that shows the precise Qibla direction (towards the Kaaba in Mecca) using the device compass and the device's current location. The app is localized and includes a welcome/splash screen, a compass-style dial with animated Qibla arrow, and helpful permission/error dialogs.

---

## Features ✅

- Animated splash and welcome screens
- Localization (multiple languages)
- Real-time compass heading (smoothened) with a rotating dial
- Precise Qibla bearing calculation (great-circle initial bearing)
- Distance to the Kaaba (Great-circle distance)
- Permission checks and friendly errors for missing sensors or denied permissions
- Settings/Permissions UI (planned)

---

## Screenshots 🖼️

> Replace the images below with real screenshots when available (place files under `/assets/screenshots/`)

| Screen | Screenshot |
|---|---|
| Home / Compass | ![Home screen](assets/screenshots/home.jpeg) |
| Welcome / Language Selector | ![Welcome screen](assets/screenshots/welcome.jpeg) |
| Permission dialog | ![Permissions](assets/screenshots/permissions.jpeg) |


---

## How it works — Qibla direction & distance 🔧

### Qibla bearing (initial great-circle bearing)

To determine the Qibla direction we compute the initial bearing (forward azimuth) from the device's location to the Kaaba coordinates (lat: 21.422487, lon: 39.826206). The implementation uses the great-circle formula for the initial bearing (also called the forward azimuth):

- Convert lat/lon to radians
- dLon = lon2 - lon1
- x = sin(dLon) * cos(lat2)
- y = cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon)
- bearing = atan2(x, y) in degrees, normalized to [0, 360)

In code: see `LocationService.qiblaBearing(lat, lon)` (lib/services/location_service.dart).

### Distance to the Kaaba (Great-circle distance)

Distance is calculated using the spherical law of cosines (a robust great-circle method):

- Convert lat/lon to radians
- dLon = lon2 - lon1
- central_angle = acos( sin(lat1)*sin(lat2) + cos(lat1)*cos(lat2)*cos(dLon) )
- distance = R * central_angle (R ≈ 6,371 km)

This is implemented in `LocationService.distanceToKaabaKm(lat, lon)`.

Why not planar math? The Earth is approximately spherical and great-circle methods provide accurate distances for any global separation.

---

## Run locally 🚀

Requirements: Flutter SDK (see https://flutter.dev), a device or emulator with location and sensors for best results.

1. Get dependencies:

```
flutter pub get
```

2. Run:

```
flutter run
```

Note: On Android you need location permission; on iOS add the required Info.plist keys (already set in this project). If you intend to show Google Maps, add your API key as described in platform files.

---

## Building release (Android AAB) 🔧

1. Place your release keystore (for example `keystore.jks`) in the `android/` folder and create `android/key.properties` with the following *local-only* values (do NOT commit this file):

```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=keystore.jks
```

A sample file `android/key.properties.example` is included in the repository to guide the format.

2. Build the Android App Bundle (AAB):

```
flutter build appbundle --release
```

3. Upload the produced AAB (`build/app/outputs/bundle/release/app-release.aab`) to the Google Play Console.

> Note: `android/key.properties` is listed in `.gitignore` by default — keep it out of source control and store secrets in CI (e.g., GitHub Actions/Secrets) for automated builds.

---

## Where to look in code 🧭

- `lib/screens/home_screen.dart` — main compass UI, loader behavior, and localized distance readout
- `lib/services/location_service.dart` — permission checks, heading stream, `qiblaBearing`, `distanceToKaabaKm`
- `lib/screens/arrow_painter.dart` — custom arrow drawing for Qibla pointer
- `assets/translations/` — translation JSON files

---

## Contribution & Notes 🛠️

- Feel free to add real screenshots to `assets/screenshots/` and update the README accordingly.
- For more precise geodesy (ellipsoidal calculations) consider using a geodesy library (e.g., vincenty or geographiclib) — current implementation is sufficient for most practical uses.

---

## QA & Test Ad Mode 🧪

This project includes a runtime "Test Ad Mode" useful for QA and debugging ad behavior.

- **Debug builds**: Test mode is automatically enabled to make testing easier.
- **Production builds**: Toggle Test Ad Mode at runtime in the app from **Settings → Test Ad Mode**; the setting is persisted (`SharedPreferences` key: `ad_test_mode`).
- When test mode is enabled the app uses Google's **test interstitial ad unit IDs** and immediately reloads the interstitial so it is ready to show.
- You can also enable test mode programmatically before initialization by calling `AdService.setTestMode(true)` (useful in automated tests).

Helpful tips for QA:

- Watch logs for `[AdService]` messages (load/show/dismiss/failure) to diagnose ad behavior.
- Use the exit/back flow to verify an interstitial shows reliably (the app awaits a short timeout while attempting to show the ad before exiting).

---

## Contact & Privacy 🔐

- **Privacy Policy:** https://onyet.github.io/privacy-police.html
- **Author / Support:**
  - WhatsApp: +62 822-2187-4400 — https://wa.me/6282221874400
  - Email: onyetcorp@gmail.com
  - Phone: +62 822-2187-4400

If you need faster support or want to report an issue, please use WhatsApp or email.

---

## Testing checklist ✔️

- Enable **Test Ad Mode** in **Settings** (or run in debug mode) and confirm the interstitial uses Google's test ad unit IDs.
- Confirm the interstitial is preloaded by resuming or opening the app (ads are refreshed on resume/start).
- Test the exit flow: press back / attempt to close the app and verify the interstitial shows (or the app exits after the short timeout).
- To re-test welcome flow in a released build, clear the app storage or use the "Reset welcome" action from Settings (or unset the `seen_welcome` SharedPreferences key).

---

License: MIT
