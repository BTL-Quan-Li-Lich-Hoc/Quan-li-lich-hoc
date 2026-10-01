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

class BetterPhenikaaScheduleApp extends StatelessWidget {
  const BetterPhenikaaScheduleApp({super.key});

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
