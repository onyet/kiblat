package id.onyet.app.kiblat

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Matrix
import android.graphics.drawable.BitmapDrawable
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetProvider

class KiblatWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.kiblat_widget)
            
            // Get widget data
            val qiblaDegree = widgetData.getFloat("qibla_degree", 0f)
            val qiblaDirection = widgetData.getString("qibla_direction", "N") ?: "N"
            val locationName = widgetData.getString("location_name", "Unknown location") ?: "Unknown location"
            val currentPrayer = widgetData.getString("current_prayer", "--") ?: "--"
            val currentPrayerTime = widgetData.getString("current_prayer_time", "--:--") ?: "--:--"
            val nextPrayer = widgetData.getString("next_prayer", "--") ?: "--"
            val nextPrayerTime = widgetData.getString("next_prayer_time", "--:--") ?: "--:--"

            // Update texts
            views.setTextViewText(R.id.qibla_degree, "${qiblaDegree.toInt()}° $qiblaDirection")
            views.setTextViewText(R.id.location_name, locationName)
            views.setTextViewText(R.id.current_prayer_name, currentPrayer)
            views.setTextViewText(R.id.current_prayer_time, currentPrayerTime)
            views.setTextViewText(R.id.next_prayer_name, nextPrayer)
            views.setTextViewText(R.id.next_prayer_time, nextPrayerTime)

            // Rotate the arrow based on qibla degree
            val rotatedBitmap = getRotatedArrowBitmap(context, qiblaDegree)
            if (rotatedBitmap != null) {
                views.setImageViewBitmap(R.id.qibla_arrow, rotatedBitmap)
            }

            // Set click intent to open the app
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, openAppPendingIntent)

            // Set refresh button click
            val refreshIntent = Intent(context, KiblatWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId))
                data = Uri.parse("homewidget://refresh")
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context,
                widgetId,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun getRotatedArrowBitmap(context: Context, degrees: Float): Bitmap? {
        try {
            val drawable = ContextCompat.getDrawable(context, R.drawable.ic_qibla_arrow)
                ?: return null
            
            val size = 200 // Size in pixels
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            
            // Save the canvas state
            canvas.save()
            
            // Rotate around center
            canvas.rotate(degrees, size / 2f, size / 2f)
            
            // Draw the drawable
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            
            // Restore canvas state
            canvas.restore()
            
            return bitmap
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
}
