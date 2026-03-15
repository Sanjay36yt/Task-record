import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/task_model.dart';

import 'dart:developer';

/// Background callback triggered when the user taps Start/Stop on the widget.
/// This runs in a separate Dart isolate and does not launch the visual app.
@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  debugPrint('WIDGET_CALLBACK: Started with URI = $uri');
  log('WIDGET_CALLBACK: Started with URI = $uri');
  
  if (uri == null) return;

  if (uri.host == 'toggleTask') {
    final taskId = uri.queryParameters['id'];
    debugPrint('WIDGET_CALLBACK: Extracted taskId = $taskId');
    if (taskId != null) {
      await _toggleTaskBackground(taskId);
    }
  }
}

Future<void> _toggleTaskBackground(String taskId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('task_recorder_tasks');
    if (list == null || list.isEmpty) return;

    final tasks = <Task>[];
    for (final s in list) {
      tasks.add(Task.fromJson(jsonDecode(s) as Map<String, dynamic>));
    }

    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = tasks[index];
    if (task.isRunning) {
      tasks[index] = task.copyWith(
        status: TaskStatus.stopped,
        elapsed: task.totalElapsed,
        clearStartedAt: true,
      );
    } else {
      tasks[index] = task.copyWith(
        status: TaskStatus.running,
        startedAt: DateTime.now(),
      );
    }

    // Save back to SharedPreferences
    final updatedList = tasks.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList('task_recorder_tasks', updatedList);

    // Filter today's tasks and calculate totals for the widget
    final today = _normalizeDate(DateTime.now());
    final todayTasks = tasks.where((t) => t.createdDate == today).toList();
    
    final runningCount = todayTasks.where((t) => t.isRunning).length;
    final totalSeconds = todayTasks.fold<int>(
      0, (acc, t) => acc + t.totalElapsed.inSeconds);
    final totalMinutes = totalSeconds ~/ 60;

    // Save to HomeWidgetPreferences (Android)
    await HomeWidget.saveWidgetData('running_count', runningCount);
    await HomeWidget.saveWidgetData('total_minutes_today', totalMinutes);
    await HomeWidget.saveWidgetData('task_recorder_tasks', updatedList.join('|||'));

    // Trigger Android widget RemoteViews redraw
    await HomeWidget.updateWidget(
      androidName: 'TaskWidgetProvider',
    );
  } catch (e) {
    debugPrint('Background callback error: $e');
  }
}

DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);
