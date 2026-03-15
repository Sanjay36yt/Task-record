package com.example.task_recorder

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import org.json.JSONArray

/**
 * TaskWidgetProvider — Android home screen widget for Task Recorder.
 */
class TaskWidgetProvider : AppWidgetProvider() {

    companion object {
        const val PREF_NAME = "HomeWidgetPreferences"

        fun updateWidgets(context: Context) {
            try {
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(
                    ComponentName(context, TaskWidgetProvider::class.java)
                )
                if (ids.isNotEmpty()) {
                    manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_task_list)
                    TaskWidgetProvider().onUpdate(context, manager, ids)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        widgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        for (id in widgetIds) {
            try {
                updateWidget(context, manager, id, prefs)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        prefs: android.content.SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.task_widget)

        val runningCount = prefs.getInt("running_count", 0)
        val totalMinutes = prefs.getInt("total_minutes_today", 0)
        val dateStr = prefs.getString("widget_date", "TODAY") ?: "TODAY"

        // Header
        views.setTextViewText(R.id.widget_date, dateStr)
        views.setTextViewText(R.id.widget_active_count, "● $runningCount Active")

        val totalHrs = totalMinutes / 60
        val totalMins = totalMinutes % 60
        views.setTextViewText(
            R.id.widget_total_time,
            "%02d:%02d Today".format(totalHrs, totalMins)
        )

        // Setup the ListView
        val serviceIntent = Intent(context, TaskWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.widget_task_list, serviceIntent)

        // Determine if list is empty by parsing the JSON quickly
        val tasksString = prefs.getString("task_recorder_tasks", "") ?: ""
        var visibleRows = 0
        if (tasksString.isNotEmpty()) {
            try {
                val arr = JSONArray("[$tasksString]".replace("|||", ","))
                visibleRows = arr.length()
            } catch (e: Exception) {}
        }

        // Show/hide empty state and list
        if (visibleRows == 0) {
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_task_list, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_empty, View.GONE)
            views.setViewVisibility(R.id.widget_task_list, View.VISIBLE)
        }

        // Setup the pending intent template for list item clicks
        // We MUST use FLAG_MUTABLE so the ListView can append the tapped item's URI data
        val intent = Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java).apply {
            action = "es.antonborri.home_widget.action.BACKGROUND"
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (android.os.Build.VERSION.SDK_INT >= 31) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        val backgroundIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
        
        views.setPendingIntentTemplate(R.id.widget_task_list, backgroundIntent)

        // Tap widget root → open app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val pi = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pi)
        }

        // Tap refresh button → force widget update
        val refreshIntent = Intent(context, TaskWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId))
        }
        val refreshPi = PendingIntent.getBroadcast(
            context, widgetId, refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_refresh_btn, refreshPi)

        // VERY IMPORTANT: Tell Android that the data inside the ListView has changed
        manager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_task_list)

        manager.updateAppWidget(widgetId, views)
    }
}
