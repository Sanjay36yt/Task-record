import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum TaskStatus { running, stopped }

enum TaskPriority { low, medium, high }

class Task {
  final String id;
  String title;
  String description;
  String category;
  TaskPriority priority;
  TaskStatus status;
  DateTime? startedAt;
  Duration elapsed;
  final DateTime createdDate;

  Task({
    String? id,
    required this.title,
    required this.description,
    this.category = 'Work',
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.stopped,
    this.startedAt,
    this.elapsed = Duration.zero,
    DateTime? createdDate,
  })  : id = id ?? _uuid.v4(),
        createdDate = createdDate ?? _today();

  bool get isRunning => status == TaskStatus.running;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Returns total time including live running time.
  /// If the app was closed while running, startedAt is restored so the gap
  /// (closed → reopened) is included automatically.
  Duration get totalElapsed {
    if (isRunning && startedAt != null) {
      return elapsed + DateTime.now().difference(startedAt!);
    }
    return elapsed;
  }

  // ── JSON serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'priority': priority.name,
        'status': status.name,
        // Always persist startedAt so we can resume the timer after restart
        'startedAt': startedAt?.toIso8601String(),
        'startedAtEpoch': startedAt?.millisecondsSinceEpoch,
        'elapsed': elapsed.inMicroseconds,
        'elapsedMs': elapsed.inMilliseconds,
        'createdDate': createdDate.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    final status = TaskStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => TaskStatus.stopped,
    );
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String? ?? 'Work',
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      status: status,
      // Restore startedAt for running tasks → totalElapsed accounts for
      // the time that passed while the app was closed
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      elapsed: Duration(microseconds: json['elapsed'] as int? ?? 0),
      createdDate: DateTime.parse(json['createdDate'] as String),
    );
  }

  Task copyWith({
    String? title,
    String? description,
    String? category,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? startedAt,
    bool clearStartedAt = false,
    Duration? elapsed,
    DateTime? createdDate,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      elapsed: elapsed ?? this.elapsed,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}
