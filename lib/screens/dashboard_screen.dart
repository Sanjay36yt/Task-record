import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';
import '../widgets/summary_bar.dart';
import 'add_task_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  // ignore: prefer_final_fields
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              pinned: true,
              backgroundColor: colorScheme.surface,
              expandedHeight: 64,
              title: const Text('Task Recorder'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Search tasks',
                  onPressed: () => _showSearch(context),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'More options',
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
              ],
            ),

            // Summary bar
            const SliverToBoxAdapter(child: SummaryBar()),

            // ── Date Navigator ──────────────────────────────────────────────
            const SliverToBoxAdapter(child: _DateNavigatorBar()),

            // Filter chips
            SliverToBoxAdapter(
              child: _FilterChipsRow(),
            ),

            // Search bar (if active)
            if (_searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Results for "$_searchQuery"',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

            // Task list
            _TaskList(searchQuery: _searchQuery),

            // Bottom padding for FAB
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _VoiceFab(),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: () => _openAddTask(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'New Task',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            tooltip: 'Add new task',
          ),
        ],
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _TaskSearchDelegate(
        context.read<TaskProvider>(),
      ),
    );
  }

  void _openAddTask(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
    );
  }
}

// ── Date Navigator Bar ────────────────────────────────────────────────────────

class _DateNavigatorBar extends StatelessWidget {
  const _DateNavigatorBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        final selected = provider.selectedDate;
        final today = _normalizeDate(DateTime.now());
        final isToday = selected == today;

        final label = isToday
            ? 'Today'
            : _formatDate(selected);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ← Previous day
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous day',
                onPressed: () {
                  provider.setSelectedDate(
                    selected.subtract(const Duration(days: 1)),
                  );
                },
              ),

              // Date label (tap to open date picker)
              GestureDetector(
                onTap: () => _pickDate(context, provider, selected, today),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        label,
                        key: ValueKey(label),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down_rounded,
                        size: 18, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),

              // → Next day (disabled when viewing today)
              IconButton(
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: isToday ? colorScheme.outlineVariant : null,
                ),
                tooltip: isToday ? 'Already on today' : 'Next day',
                onPressed: isToday
                    ? null
                    : () {
                        provider.setSelectedDate(
                          selected.add(const Duration(days: 1)),
                        );
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    TaskProvider provider,
    DateTime current,
    DateTime today,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null) {
      provider.setSelectedDate(picked);
    }
  }

  static DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday]}, ${months[d.month]} ${d.day}';
  }
}

// ── Filter Chips ──────────────────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip(
                  context,
                  label: 'All',
                  icon: Icons.list_alt_rounded,
                  filter: FilterState.all,
                  provider: provider,
                  colorScheme: colorScheme,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _buildChip(
                  context,
                  label: 'Running',
                  icon: Icons.play_circle_rounded,
                  filter: FilterState.running,
                  provider: provider,
                  colorScheme: colorScheme,
                  theme: theme,
                  activeColor: const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 8),
                _buildChip(
                  context,
                  label: 'Stopped',
                  icon: Icons.stop_circle_rounded,
                  filter: FilterState.stopped,
                  provider: provider,
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required FilterState filter,
    required TaskProvider provider,
    required ColorScheme colorScheme,
    required ThemeData theme,
    Color? activeColor,
  }) {
    final isSelected = provider.filter == filter;
    final selectedColor = activeColor ?? colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? selectedColor : colorScheme.onSurfaceVariant,
          ),
        ),
        avatar: Icon(
          icon,
          size: 16,
          color: isSelected ? selectedColor : colorScheme.onSurfaceVariant,
        ),
        selectedColor: selectedColor.withOpacity(0.15),
        checkmarkColor: selectedColor,
        showCheckmark: false,
        onSelected: (_) => provider.setFilter(filter),
      ),
    );
  }
}

// ── Task List ─────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final String searchQuery;

  const _TaskList({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        var tasks = provider.filteredTasks;
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          tasks = tasks
              .where((t) =>
                  t.title.toLowerCase().contains(q) ||
                  t.description.toLowerCase().contains(q) ||
                  t.category.toLowerCase().contains(q))
              .toList();
        }

        if (tasks.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tasks for this day',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap + to add a task or pick another date',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Dismissible(
              key: ValueKey(task.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.delete_rounded,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
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
              },
              onDismissed: (_) {
                context.read<TaskProvider>().deleteTask(task.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${task.title}" deleted'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: TaskCard(task: task),
            );
          },
        );
      },
    );
  }
}

// ── Search Delegate ───────────────────────────────────────────────────────────

class _TaskSearchDelegate extends SearchDelegate<String> {
  final TaskProvider provider;

  _TaskSearchDelegate(this.provider);

  @override
  String get searchFieldLabel => 'Search tasks...';

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
            icon: const Icon(Icons.clear_rounded), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.toLowerCase();
    final results = provider.allTasks
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q))
        .toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) => TaskCard(task: results[i]),
    );
  }
}

// ── Voice FAB ─────────────────────────────────────────────────────────────────

class _VoiceFab extends StatefulWidget {
  @override
  State<_VoiceFab> createState() => _VoiceFabState();
}

class _VoiceFabState extends State<_VoiceFab>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;
  bool _stopRequested = false;   // prevents double-processing
  String _lastWords = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        // Called when speech recognition stops (timeout or manual stop)
        if ((status == 'done' || status == 'notListening') && _isListening) {
          _handleResult();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          _stopRequested = false;
          // Only show error if it's not a "no match" (silence) error
          if (error.errorMsg != 'error_no_match') {
            _showSnack('Mic error: ${error.errorMsg}');
          } else {
            _showSnack('No speech detected — try again');
          }
        }
      },
    );
    if (mounted) setState(() => _isAvailable = available);
  }

  void _startListening() async {
    if (!_isAvailable || _isListening) return;
    HapticFeedback.mediumImpact();
    _stopRequested = false;
    setState(() {
      _isListening = true;
      _lastWords = '';
    });
    // pauseFor is large so it doesn't cut off mid-sentence (between words)
    // No localeId — uses device's default speech recognition language
    await _speech.listen(
      onResult: (result) {
        // Always keep the latest recognized words (partial + final)
        if (mounted) setState(() => _lastWords = result.recognizedWords);
        // When user has released AND the engine gives a final result → done
        if (_stopRequested && result.finalResult) {
          _handleResult();
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 8), // big pause so multi-word phrases aren't cut
    );
  }

  void _stopListening() {
    if (!_isListening) return;
    _stopRequested = true;
    _speech.stop(); // asks engine to finalize → fires onResult(finalResult:true) or onStatus 'done'
    // Safety fallback: if engine doesn't give finalResult within 2s, process with what we have
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (_isListening && mounted) _handleResult();
    });
  }

  void _handleResult() {
    if (!mounted || !_isListening) return;
    setState(() => _isListening = false);
    _stopRequested = false;

    final text = _lastWords.trim();
    if (text.isEmpty) {
      _showSnack('Nothing heard — hold and speak clearly');
      return;
    }

    // Auto-create and immediately start the task
    context.read<TaskProvider>().addTask(
          title: _capitalize(text),
          description: 'Created via voice',
          autoStart: true,
        );
    HapticFeedback.lightImpact();
    _showSnack('✅ "${_capitalize(text)}" started!');
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final listeningColor = Colors.redAccent.shade400;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // "Listening…" label visible only while recording
        AnimatedOpacity(
          opacity: _isListening ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6, right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: listeningColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🎤 Listening…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        // Mic button — use GestureDetector on a Material widget (avoids FAB conflicts)
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale = _isListening ? _pulseAnimation.value : 1.0;
            return Transform.scale(scale: scale, child: child);
          },
          child: Tooltip(
            message: _isAvailable
                ? 'Hold to speak your task name'
                : 'Speech recognition not available',
            child: GestureDetector(
              onLongPressStart: (_) => _startListening(),
              onLongPressEnd: (_) => _stopListening(),
              onTap: () => _showSnack(
                  '🎤 Hold this button and speak your task name'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isAvailable
                      ? (_isListening
                          ? listeningColor
                          : colorScheme.secondaryContainer)
                      : colorScheme.surfaceContainerHighest,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? listeningColor : colorScheme.shadow)
                          .withOpacity(_isListening ? 0.4 : 0.15),
                      blurRadius: _isListening ? 16 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    key: ValueKey(_isListening),
                    color: _isListening
                        ? Colors.white
                        : (_isAvailable
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.outlineVariant),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


