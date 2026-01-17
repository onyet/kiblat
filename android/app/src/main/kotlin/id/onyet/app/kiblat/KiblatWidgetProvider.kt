package id.onyet.app.kiblat

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.Log
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Kiblat Home Screen Widget Provider
 * 
 * Prinsip utama (dari WIDGET_HOME.md):
 * - Widget HARUS bisa dirender walau semua data NULL
 * - Selalu bungkus logic dengan try-catch
 * - Selalu set default value
 * - Widget TIDAK BOLEH akses GPS/sensor/network langsung
 * - Gunakan cache sebagai sumber utama
 */
class KiblatWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val TAG = "KiblatWidget"
        
        // Default values untuk fallback
        private const val DEFAULT_QIBLA_DEGREE = 0f
        private const val DEFAULT_DIRECTION = "N"
        private const val DEFAULT_LOCATION = "Buka app untuk update"
        private const val DEFAULT_PRAYER = "--"
        private const val DEFAULT_TIME = "--:--"
        
        // Arrow bitmap size (smaller for horizontal layout)
        private const val ARROW_SIZE = 120
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, widgetId, widgetData)
            } catch (e: Exception) {
                Log.w(TAG, "Error updating widget $widgetId, rendering fallback", e)
                renderFallbackWidget(context, appWidgetManager, widgetId)
            }
        }
    }

    /**
     * Update widget dengan data dari SharedPreferences
     */
    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.kiblat_widget)
        
        // Ambil data dengan safe defaults (null safety)
        val qiblaDegree = try {
            widgetData.getFloat("qibla_degree", DEFAULT_QIBLA_DEGREE)
        } catch (e: Exception) {
            DEFAULT_QIBLA_DEGREE
        }
        
        val qiblaDirection = widgetData.getString("qibla_direction", DEFAULT_DIRECTION) 
            ?: DEFAULT_DIRECTION
            
        val locationName = widgetData.getString("location_name", DEFAULT_LOCATION)
            ?: DEFAULT_LOCATION
            
        val currentPrayer = widgetData.getString("current_prayer", DEFAULT_PRAYER)
            ?: DEFAULT_PRAYER
            
        val currentPrayerTime = widgetData.getString("current_prayer_time", DEFAULT_TIME)
            ?: DEFAULT_TIME
            
        val nextPrayer = widgetData.getString("next_prayer", DEFAULT_PRAYER)
            ?: DEFAULT_PRAYER
            
        val nextPrayerTime = widgetData.getString("next_prayer_time", DEFAULT_TIME)
            ?: DEFAULT_TIME

        // Update texts dengan try-catch per item
        try {
            views.setTextViewText(R.id.qibla_degree, "${qiblaDegree.toInt()}° $qiblaDirection")
        } catch (e: Exception) {
            views.setTextViewText(R.id.qibla_degree, "0° N")
        }
        
        try {
            views.setTextViewText(R.id.location_name, locationName)
        } catch (e: Exception) {
            views.setTextViewText(R.id.location_name, DEFAULT_LOCATION)
        }
        
        try {
            views.setTextViewText(R.id.current_prayer_name, currentPrayer)
            views.setTextViewText(R.id.current_prayer_time, currentPrayerTime)
        } catch (e: Exception) {
            views.setTextViewText(R.id.current_prayer_name, DEFAULT_PRAYER)
            views.setTextViewText(R.id.current_prayer_time, DEFAULT_TIME)
        }
        
        try {
            views.setTextViewText(R.id.next_prayer_name, nextPrayer)
            views.setTextViewText(R.id.next_prayer_time, nextPrayerTime)
        } catch (e: Exception) {
            views.setTextViewText(R.id.next_prayer_name, DEFAULT_PRAYER)
            views.setTextViewText(R.id.next_prayer_time, DEFAULT_TIME)
        }

        // Rotate arrow berdasarkan qibla degree (dengan fallback)
        try {
            val rotatedBitmap = getRotatedArrowBitmap(context, qiblaDegree)
            if (rotatedBitmap != null) {
                views.setImageViewBitmap(R.id.qibla_arrow, rotatedBitmap)
            }
            // Jika bitmap null, biarkan default dari XML
        } catch (e: Exception) {
            Log.w(TAG, "Failed to rotate arrow, using default", e)
            // Biarkan arrow default dari layout XML
        }

        // Set click intent untuk buka app (dengan try-catch)
        try {
            setupClickIntents(context, views, widgetId)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to setup click intents", e)
        }

        // Update widget
        try {
            appWidgetManager.updateAppWidget(widgetId, views)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update widget", e)
        }
    }

    /**
     * Render widget dengan tampilan fallback (safe state)
     * Dipanggil jika terjadi error saat update
     */
    private fun renderFallbackWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        try {
            val views = RemoteViews(context.packageName, R.layout.kiblat_widget)
            
            // Set default texts
            views.setTextViewText(R.id.qibla_degree, "0° N")
            views.setTextViewText(R.id.location_name, DEFAULT_LOCATION)
            views.setTextViewText(R.id.current_prayer_name, DEFAULT_PRAYER)
            views.setTextViewText(R.id.current_prayer_time, DEFAULT_TIME)
            views.setTextViewText(R.id.next_prayer_name, DEFAULT_PRAYER)
            views.setTextViewText(R.id.next_prayer_time, DEFAULT_TIME)
            
            // Setup click intents
            try {
                setupClickIntents(context, views, widgetId)
            } catch (e: Exception) {
                // Ignore - widget will still render
            }
            
            appWidgetManager.updateAppWidget(widgetId, views)
        } catch (e: Exception) {
            Log.e(TAG, "Even fallback widget failed!", e)
        }
    }

    /**
     * Setup click intents untuk widget
     */
    private fun setupClickIntents(context: Context, views: RemoteViews, widgetId: Int) {
        // Click pada widget container untuk buka app
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

        // Click pada refresh button
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
    }

    /**
     * Rotate arrow bitmap berdasarkan derajat
     * Returns null jika gagal (caller harus handle)
     */
    private fun getRotatedArrowBitmap(context: Context, degrees: Float): Bitmap? {
        return try {
            val drawable = ContextCompat.getDrawable(context, R.drawable.ic_qibla_arrow)
                ?: return null
            
            val bitmap = Bitmap.createBitmap(ARROW_SIZE, ARROW_SIZE, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            
            canvas.save()
            canvas.rotate(degrees, ARROW_SIZE / 2f, ARROW_SIZE / 2f)
            
            drawable.setBounds(0, 0, ARROW_SIZE, ARROW_SIZE)
            drawable.draw(canvas)
            
            canvas.restore()
            
            bitmap
        } catch (e: Exception) {
            Log.w(TAG, "Failed to create rotated bitmap", e)
            null
        }
    }

    /**
     * Called when widget is first created
     */
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d(TAG, "Widget enabled")
    }

    /**
     * Called when last widget is removed
     */
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        Log.d(TAG, "Widget disabled")
    }
}
