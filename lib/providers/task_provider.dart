import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

enum FilterState { all, running, stopped }

class TaskProvider extends ChangeNotifier {
  final List<Task> _tasks = [];
  FilterState _filter = FilterState.all;
  Timer? _ticker;
  DateTime _selectedDate = _normalizeDate(DateTime.now());

  static const _storageKey = 'task_recorder_tasks';
  static const _widgetName = 'TaskWidgetProvider';

  TaskProvider() {
    _startTicker();
    _loadFromStorage();
  }

  static DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  // ── Getters ───────────────────────────────────────────────────────────────

  List<Task> get allTasks => List.unmodifiable(_tasks);
  FilterState get filter => _filter;
  DateTime get selectedDate => _selectedDate;

  List<Task> get tasksForSelectedDate =>
      _tasks.where((t) => t.createdDate == _selectedDate).toList();

  List<Task> get filteredTasks {
    final dateTasks = tasksForSelectedDate;
    switch (_filter) {
      case FilterState.running:
        return dateTasks.where((t) => t.isRunning).toList();
      case FilterState.stopped:
        return dateTasks.where((t) => !t.isRunning).toList();
      case FilterState.all:
        return dateTasks;
    }
  }

  int get activeTaskCount =>
      tasksForSelectedDate.where((t) => t.isRunning).length;

  Duration get totalElapsedToday =>
      tasksForSelectedDate.fold(Duration.zero, (acc, t) => acc + t.totalElapsed);

  // ── Mutations ─────────────────────────────────────────────────────────────

  void setFilter(FilterState f) { _filter = f; notifyListeners(); }

  void setSelectedDate(DateTime date) {
    _selectedDate = _normalizeDate(date);
    notifyListeners();
  }

  void addTask({
    required String title,
    required String description,
    String category = 'Work',
    TaskPriority priority = TaskPriority.medium,
    bool autoStart = false,
  }) {
    final task = Task(
      title: title,
      description: description,
      category: category,
      priority: priority,
      status: autoStart ? TaskStatus.running : TaskStatus.stopped,
      startedAt: autoStart ? DateTime.now() : null,
      createdDate: _normalizeDate(DateTime.now()),
    );
    _tasks.insert(0, task);
    _saveAndUpdateWidget();
    notifyListeners();
  }

  void toggleTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final task = _tasks[index];
    if (task.isRunning) {
      _tasks[index] = task.copyWith(
        status: TaskStatus.stopped,
        elapsed: task.totalElapsed,
        clearStartedAt: true,
      );
    } else {
      _tasks[index] = task.copyWith(
        status: TaskStatus.running,
        startedAt: DateTime.now(),
      );
    }
    _saveAndUpdateWidget();
    notifyListeners();
  }

  void deleteTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    _saveAndUpdateWidget();
    notifyListeners();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _saveAndUpdateWidget() async {
    await _save();
    await _pushWidgetData();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _tasks.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList(_storageKey, list);
    } catch (e) {
      debugPrint('TaskProvider._save: $e');
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey);
      if (list != null && list.isNotEmpty) {
        _tasks.clear();
        for (final s in list) {
          try {
            _tasks.add(Task.fromJson(jsonDecode(s) as Map<String, dynamic>));
          } catch (e) {
            debugPrint('TaskProvider: skip corrupt task: $e');
          }
        }
        notifyListeners();
        await _pushWidgetData();
        return;
      }
    } catch (e) {
      debugPrint('TaskProvider._load: $e');
    }
    notifyListeners();
    await _pushWidgetData();
  }

  /// Pushes all data that the widget needs to HomeWidget SharedPreferences,
  /// then triggers a widget redraw.
  Future<void> _pushWidgetData() async {
    try {
      final today = _normalizeDate(DateTime.now());
      final todayTasks = _tasks.where((t) => t.createdDate == today).toList();
      final runningTasks = todayTasks.where((t) => t.isRunning).toList();

      final totalSeconds = todayTasks.fold<int>(
        0, (acc, t) => acc + t.totalElapsed.inSeconds);
      final totalMinutes = totalSeconds ~/ 60;

      final now = DateTime.now();
      final monthNames = ['JAN','FEB','MAR','APR','MAY','JUN',
                          'JUL','AUG','SEP','OCT','NOV','DEC'];
      final dateStr = '${monthNames[now.month - 1]} ${now.day}';

      await HomeWidget.saveWidgetData('running_count', runningTasks.length);
      await HomeWidget.saveWidgetData('total_minutes_today', totalMinutes);
      await HomeWidget.saveWidgetData('widget_date', dateStr);

      // Save full task JSON so Android ListView can parse all tasks
      final jsonList = _tasks.map((t) => jsonEncode(t.toJson())).toList();
      await HomeWidget.saveWidgetData('task_recorder_tasks', jsonList.join('|||'));

      await HomeWidget.updateWidget(
        androidName: _widgetName,
        iOSName: _widgetName,
      );
    } catch (e) {
      debugPrint('TaskProvider._pushWidgetData: $e');
    }
  }

  // ── Ticker ────────────────────────────────────────────────────────────────

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tasks.any((t) => t.isRunning)) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
