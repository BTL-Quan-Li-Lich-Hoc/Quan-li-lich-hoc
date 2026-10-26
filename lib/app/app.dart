import 'dart:async';

import 'package:better_phenikaa_schedule/app/schedule_coordinator.dart';
import 'package:better_phenikaa_schedule/features/exam/exam_screen.dart';
import 'package:better_phenikaa_schedule/features/timetable/timetable_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/timetable',
  routes: <RouteBase>[
    ShellRoute(
      builder: (context, state, child) {
        return _AppShell(location: state.uri.path, child: child);
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/timetable',
          builder: (context, state) => const TimetableScreen(),
        ),
        GoRoute(
          path: '/exam',
          builder: (context, state) => const ExamScreen(),
        ),
      ],
    ),
  ],
);

class BetterPhenikaaScheduleApp extends StatefulWidget {
  const BetterPhenikaaScheduleApp({super.key});

  @override
  State<BetterPhenikaaScheduleApp> createState() =>
      _BetterPhenikaaScheduleAppState();
}

class _BetterPhenikaaScheduleAppState extends State<BetterPhenikaaScheduleApp> {
  @override
  void initState() {
    super.initState();
    unawaited(scheduleCoordinator.load());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Better Phenikaa Schedule',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.location, required this.child});

  final String location;
  final Widget child;

  int get _selectedIndex => location.startsWith('/exam') ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go('/timetable');
          } else {
            context.go('/exam');
          }
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.calendar_view_week_outlined),
            selectedIcon: Icon(Icons.calendar_view_week),
            label: 'Lịch học',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Lịch thi',
          ),
        ],
      ),
    );
  }
}
