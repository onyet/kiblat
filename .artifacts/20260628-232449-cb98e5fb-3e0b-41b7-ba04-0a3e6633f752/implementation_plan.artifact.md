# Prayer Log Redesign and Enhancements

Redesign the Prayer Tracker screen for a more professional look, reposition components, add JSON export for Pro users, fix badge theming in settings, and address the compass/gyro issue.

## User Review Required

- **Compass/Gyro Issue**: I suspect some devices report sensors as available but don't emit events or report zero values. I will add a "Manual Calibration" or "Sensor Reset" hint if no movement is detected.

## Proposed Changes

### Prayer Tracker

#### [prayer_tracker_screen.dart](file:///Users/onyet/Onyet_Apps/kiblat/lib/screens/prayer_tracker_screen.dart)
- Reposition components:
    1. Summary Card (Keep at top or integrate with Today Log)
    2. **[TOP]** Today Prayer Log (Checklist) - Redesign for professional look.
    3. Prayer Insights (Pro)
    4. Prayer History (List)
    5. **[BOTTOM]** Prayer Heatmap.
- Update `_exportLogs` to support JSON format for Pro users.
- Redesign checklist items with better typography and icons.

#### [prayer_heatmap.dart](file:///Users/onyet/Onyet_Apps/kiblat/lib/widgets/prayer_heatmap.dart)
- Minor styling adjustments to match the professional redesign.

### Settings Screen

#### [settings_screen.dart](file:///Users/onyet/Onyet_Apps/kiblat/lib/screens/settings_screen.dart)
- Update `_statusChip` to use theme-aware colors (Accent color for active/available instead of hardcoded green).

### Localization

#### [all translation files](file:///Users/onyet/Onyet_Apps/kiblat/assets/translations/)
- Audit and add missing keys: `tasbih`, `ar_warning_title`, `ar_warning_msg`, `proceed`, `prayer_heatmap`, `location_history`, `no_location_history`, `export_json`, etc.

### Compass Service

#### [location_service.dart](file:///Users/onyet/Onyet_Apps/kiblat/lib/services/location_service.dart)
- Add a check for "stale" compass data. If the heading doesn't change for a while despite device movement (detected via accelerometer/gyro if available), suggest calibration.

## Verification Plan

### Manual Verification
1. **Prayer Tracker**: Verify the new order of components and the professional redesign.
2. **JSON Export**: Check if Pro users can export history in JSON format.
3. **Badge Theming**: Verify status badges in Settings change color based on selected accent theme.
4. **Translations**: Switch languages and check for missing text or `key_not_found`.
5. **Compass Check**: Simulate stale data (if possible) to see if a hint/warning appears.
