# Move Tasbih to Main Navigation and Optimize UI

Move the Tasbih feature from a floating button to a dedicated fourth tab in the main navigation. Make it accessible to all users and relocate banner ads from the Settings screen to the Tasbih screen.

## Proposed Changes

### Navigation

#### [main_shell.dart](file:///Users/onyet/Onyet_Apps/kiblat/lib/screens/main_shell.dart)
- Update `_screens` to include `TasbihScreen` as the 4th item.
- Add a new `_buildNavItem` for Tasbih with appropriate icons and label.
- Adjust the layout to accommodate 4 items in the bottom navigation.

### Tasbih Feature

#### [tasbih_screen.dart](file:///Users/onyet/Onyet_Apps/kiblat/lib/screens/tasbih/tasbih_screen.dart)
- Remove the `leading` back button from `AppBar`.
- Update `title` from "Tasbih Digital Pro" to "Tasbih Digital" (since it's now for everyone).
- Implement `BannerAd` logic similar to `SettingsScreen`.
- Add `AdWidget` at the bottom of the screen for non-pro users.

#### [home_screen.dart](file:///Users/onyet/Onyet_Apps/kiblat/lib/screens/home_screen.dart)
- Remove the `FloatingActionButton` that currently opens Tasbih.
- Remove `_handleTasbihTap` function.

### Settings Screen

#### [settings_screen.dart](file:///Users/onyet/Onyet_Apps/kiblat/lib/screens/settings_screen.dart)
- Remove `BannerAd` initialization, disposal, and rendering logic.
- Clean up related state variables like `_bannerAd` and `_bannerLoaded`.

### Localization

#### [in.json](file:///Users/onyet/Onyet_Apps/kiblat/assets/translations/in.json) & [en.json](file:///Users/onyet/Onyet_Apps/kiblat/assets/translations/en.json)
- Ensure "tasbih" label exists for the navigation bar.

## Verification Plan

### Manual Verification
1. **Navigation Check**: Verify that a 4th tab with the Tasbih icon appears in the Bottom Navigation.
2. **Tab Switching**: Confirm switching to the Tasbih tab works and it doesn't have a back button.
3. **Ad Placement**: Verify that the banner ad appears at the bottom of the Tasbih screen (for non-pro) and NO LONGER appears in the Settings screen.
4. **Pro Status**: Check that the banner ad is hidden on the Tasbih screen if the user is a Pro user.
5. **Home Screen**: Confirm the Floating Action Button is gone from the Compass screen.
