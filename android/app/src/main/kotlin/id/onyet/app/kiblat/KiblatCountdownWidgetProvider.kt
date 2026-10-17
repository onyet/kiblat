package id.onyet.app.kiblat

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Compact "Next Prayer" countdown widget (Pro data via shared home_widget prefs).
 */
class KiblatCountdownWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val TAG = "KiblatCountdownWidget"
        private const val DEFAULT_PRAYER = "--"
        private const val DEFAULT_TIME = "--:--"
        private const val DEFAULT_LOCATION = "Kiblat"
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
                Log.w(TAG, "Update failed for $widgetId", e)
                renderFallback(context, appWidgetManager, widgetId)
            }
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.kiblat_countdown_widget)
        val nextPrayer = widgetData.getString("next_prayer", DEFAULT_PRAYER) ?: DEFAULT_PRAYER
        val nextTime = widgetData.getString("next_prayer_time", DEFAULT_TIME) ?: DEFAULT_TIME
        val location = widgetData.getString("location_name", DEFAULT_LOCATION) ?: DEFAULT_LOCATION

        views.setTextViewText(R.id.countdown_next_label, context.getString(R.string.countdown_widget_next))
        views.setTextViewText(R.id.countdown_prayer_name, nextPrayer)
        views.setTextViewText(R.id.countdown_prayer_time, nextTime)
        views.setTextViewText(R.id.countdown_location, location)

        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            context,
            1,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.countdown_widget_container, pending)

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun renderFallback(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        try {
            val views = RemoteViews(context.packageName, R.layout.kiblat_countdown_widget)
            views.setTextViewText(R.id.countdown_prayer_name, DEFAULT_PRAYER)
            views.setTextViewText(R.id.countdown_prayer_time, DEFAULT_TIME)
            appWidgetManager.updateAppWidget(widgetId, views)
        } catch (e: Exception) {
            Log.e(TAG, "Fallback failed", e)
        }
    }
}
