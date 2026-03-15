import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'providers/task_provider.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';
import 'widget_callback.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Register the background isolate callback for widget button taps
  await HomeWidget.registerInteractivityCallback(interactiveCallback);
  runApp(
    ChangeNotifierProvider(
      create: (_) => TaskProvider(),
      child: const TaskRecorderApp(),
    ),
  );
}

class TaskRecorderApp extends StatelessWidget {
  const TaskRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Recorder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const DashboardScreen(),
    );
  }
}
