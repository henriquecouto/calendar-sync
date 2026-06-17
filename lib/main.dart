import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/dashboard_screen.dart';
import 'permissions/permission_gate.dart';
import 'background/sync_task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);
  runApp(const CalendarSyncApp());
}

class CalendarSyncApp extends StatelessWidget {
  const CalendarSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme = lightDynamic ?? ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        );
        final darkScheme = darkDynamic ?? ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        );

        final lightTheme = ThemeData(
          colorScheme: lightScheme,
          useMaterial3: true,
        );

        final darkTheme = ThemeData(
          colorScheme: darkScheme,
          useMaterial3: true,
        );

        return MaterialApp(
          title: 'CalSync',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.system,
          home: const _SyncedGate(),
        );
      },
    );
  }
}

class _SyncedGate extends StatelessWidget {
  const _SyncedGate();

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      child: Builder(
        builder: (context) {
          return const DashboardScreen();
        },
      ),
    );
  }
}
