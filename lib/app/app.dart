import 'dart:async';
import 'package:better_phenikaa_schedule/app/schedule_coordinator.dart';
import 'package:better_phenikaa_schedule/features/local_data_sync/local_schedule_store.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_service.dart';
import 'package:better_phenikaa_schedule/features/account/account_screen.dart';
import 'package:better_phenikaa_schedule/features/exam/exam_screen.dart';
import 'package:better_phenikaa_schedule/features/qldt_intake/qldt_login_screen.dart';
import 'package:better_phenikaa_schedule/features/timetable/timetable_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/timetable',
  routes: <RouteBase>[
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return const QldtLoginScreen();
      },
    ),
    ShellRoute(
      builder: (
        BuildContext context,
        GoRouterState state,
        Widget child,
      ) {
        return _AppShell(location: state.uri.path, child: child);
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/timetable',
          builder: (BuildContext context, GoRouterState state) {
            return const TimetableScreen();
          },
        ),
        GoRoute(
          path: '/exam',
          builder: (BuildContext context, GoRouterState state) {
            return const ExamScreen();
          },
        ),
        GoRoute(
          path: '/account',
          builder: (BuildContext context, GoRouterState state) {
            return const AccountScreen();
          },
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
  LocalScheduleStore? _store;

  @override
  void initState() {
    super.initState();
    unawaited(_openCachedSchedule());
  }

  Future<void> _openCachedSchedule() async {
    try {
      final store = await LocalScheduleStore.open();
      if (!mounted) {
        await store.dispose();
        return;
      }
      _store = store;
      scheduleCoordinator.attachRepositories(
        scheduleRepository: store,
        examRepository: store,
      );
      await scheduleCoordinator.load();
      await WidgetService(
        scheduleRepository: store,
        snapshotRepository: store,
      ).refresh(selectedDate: scheduleCoordinator.selectedDay);
    } on Object catch (error) {
      if (mounted) scheduleCoordinator.showError(error);
    }
  }

  @override
  void dispose() {
    final store = _store;
    if (store != null) unawaited(store.dispose());
    super.dispose();
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
  const _AppShell({
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  int get _selectedIndex {
    if (location.startsWith('/exam')) return 1;
    if (location.startsWith('/account')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          switch (index) {
            case 0:
              context.go('/timetable');
              return;
            case 1:
              context.go('/exam');
              return;
            case 2:
              context.go('/account');
              return;
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
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
