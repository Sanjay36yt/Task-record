import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRunning = task.isRunning;

    const runningColor = Color(0xFF4CAF50);
    final stoppedColor = colorScheme.outline;
    final borderColor = isRunning ? runningColor : Colors.transparent;
    final indicatorColor = isRunning ? runningColor : stoppedColor;

    // RepaintBoundary: GPU caches the static card content; only _LiveTimer
    // repaints every second, not the whole card.
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isRunning ? 1.5 : 0),
          color: isRunning
              ? Color.alphaBlend(
                  runningColor.withValues(alpha: 0.06),
                  colorScheme.surfaceContainerLow,
                )
              : colorScheme.surfaceContainerLow,
          boxShadow: isRunning
              ? [
                  BoxShadow(
                    color: runningColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left indicator bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 4,
                  color: indicatorColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: title + status chip + delete icon
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(isRunning: isRunning),
                            const SizedBox(width: 4),
                            _DeleteButton(task: task),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Description
                        Text(
                          task.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        // Category + live timer row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                task.category,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Only this widget rebuilds every second
                            _LiveTimer(
                              taskId: task.id,
                              isRunning: isRunning,
                              runningColor: runningColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Start time + toggle
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              task.startedAt != null
                                  ? _formatStartTime(task.startedAt!)
                                  : task.elapsed > Duration.zero
                                      ? 'Elapsed: ${_formatDuration(task.elapsed)}'
                                      : 'Not started',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            _ToggleButton(task: task),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatStartTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return 'Started $hour:$minute $period';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ── Live Timer (Selector-based) ───────────────────────────────────────────────

/// Subscribes only to this task's elapsed time.
/// Rebuilds the timer display every second WITHOUT touching the parent card.
class _LiveTimer extends StatelessWidget {
  final String taskId;
  final bool isRunning;
  final Color runningColor;

  const _LiveTimer({
    required this.taskId,
    required this.isRunning,
    required this.runningColor,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<TaskProvider, Duration>(
      selector: (_, p) {
        final task = p.allTasks.firstWhere(
          (t) => t.id == taskId,
          orElse: () => Task(title: '', description: ''),
        );
        return task.totalElapsed;
      },
      builder: (_, elapsed, __) => _TimerDisplay(
        elapsed: elapsed,
        isRunning: isRunning,
        runningColor: runningColor,
      ),
    );
  }
}

// ── Timer Display ─────────────────────────────────────────────────────────────

class _TimerDisplay extends StatelessWidget {
  final Duration elapsed;
  final bool isRunning;
  final Color runningColor;

  const _TimerDisplay({
    required this.elapsed,
    required this.isRunning,
    required this.runningColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isRunning)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _PulsingDot(color: runningColor),
          ),
        Text(
          '$h:$m:$s',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isRunning ? runningColor : colorScheme.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ── Pulsing Dot ───────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

// ── Status Chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final bool isRunning;
  const _StatusChip({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    const runningColor = Color(0xFF4CAF50);
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isRunning
            ? runningColor.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isRunning ? 'Running' : 'Stopped',
        style: theme.textTheme.labelSmall?.copyWith(
          color: isRunning ? runningColor : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Toggle Button ─────────────────────────────────────────────────────────────

class _ToggleButton extends StatelessWidget {
  final Task task;
  const _ToggleButton({required this.task});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TaskProvider>();
    const runningColor = Color(0xFF4CAF50);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => provider.toggleTask(task.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: task.isRunning
              ? runningColor
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              task.isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 16,
              color: task.isRunning ? Colors.white : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              task.isRunning ? 'Stop' : 'Start',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: task.isRunning
                    ? Colors.white
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Delete Button ─────────────────────────────────────────────────────────────

class _DeleteButton extends StatelessWidget {
  final Task task;
  const _DeleteButton({required this.task});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(Icons.delete_outline_rounded,
            color: colorScheme.outlineVariant),
        tooltip: 'Delete task',
        onPressed: () => _confirmDelete(context),
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<TaskProvider>().deleteTask(task.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${task.title}" deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
