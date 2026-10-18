# Local patches (kiblat)

Based on `flutter_local_notifications` 19.5.0.

## Android bitmap downsampling

Play Console flags `BitmapFactory.decode*` without `BitmapFactory.Options`.

`FlutterLocalNotificationsPlugin` now decodes drawable / file / byte-array / Flutter-asset bitmaps with `inSampleSize` (max edge 256px) so notification large icons do not load full-resolution images.
