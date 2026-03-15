package com.example.task_recorder

import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import org.json.JSONArray
import org.json.JSONObject

class TaskWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TaskRemoteViewsFactory(this.applicationContext)
    }
}

class TaskRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private var tasks = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        // Read the latest JSON string saved by Flutter
        val prefs = context.getSharedPreferences(TaskWidgetProvider.PREF_NAME, Context.MODE_PRIVATE)
        val tasksString = prefs.getString("task_recorder_tasks", "") ?: ""
        
        tasks = JSONArray()
        if (tasksString.isNotEmpty()) {
            val jsonArrayStr = "[$tasksString]".replace("|||", ",")
            try {
                tasks = JSONArray(jsonArrayStr)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onDestroy() {}

    override fun getCount(): Int = tasks.length()

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.task_widget_list_item)
        try {
            val taskObj = tasks.getJSONObject(position)
            val taskId = taskObj.optString("id", "")
            val title = taskObj.optString("title", "Task")
            val isRunning = taskObj.optString("status") == "running"
            val frozenElapsedMs = taskObj.optLong("elapsedMs", 0L)

            views.setTextViewText(R.id.row_task_title, title)

            if (isRunning) {
                // Calculate exactly how long it's been running since the start button was pressed
                val startedAtEpoch = taskObj.optLong("startedAtEpoch", 0L)
                var timeRunningMs = 0L
                if (startedAtEpoch > 0) {
                    timeRunningMs = System.currentTimeMillis() - startedAtEpoch
                }
                
                // Total elapsed in ms = frozen elapsed + time currently running
                val totalElapsedMs = frozenElapsedMs + timeRunningMs
                
                // Calculate baseTime relative to Android's elapsedRealtime (boot time)
                val baseTime = SystemClock.elapsedRealtime() - totalElapsedMs
                
                views.setChronometer(R.id.row_task_elapsed, baseTime, null, true)
                // Force Chronometer ticking inside ListView on API 26+
                views.setBoolean(R.id.row_task_elapsed, "setStarted", true)
            } else {
                // If stopped, base time is simply elapsedRealtime minus frozen duration
                val baseTime = SystemClock.elapsedRealtime() - frozenElapsedMs
                views.setChronometer(R.id.row_task_elapsed, baseTime, null, false)
                views.setBoolean(R.id.row_task_elapsed, "setStarted", false)
            }

            views.setTextViewText(R.id.row_task_btn, if (isRunning) "■" else "▶")
            views.setInt(
                R.id.row_task_btn, "setBackgroundResource",
                if (isRunning) R.drawable.widget_stop_btn else R.drawable.widget_start_btn
            )

            // CRITICAL FIX: The template PendingIntent must NOT have 'data' set.
            // FillInIntent will only fill-in fields that are EMPTY in the template.
            // We set the URI here (in the fill-in) and leave the template data empty.
            // This ensures every row's task ID is correctly forwarded to the Dart callback.
            val fillInIntent = Intent().apply {
                data = android.net.Uri.parse("toggleTask://toggleTask?id=$taskId")
                action = "es.antonborri.home_widget.action.BACKGROUND"
            }
            views.setOnClickFillInIntent(R.id.row_task_btn, fillInIntent)

        } catch (e: Exception) {
            e.printStackTrace()
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
