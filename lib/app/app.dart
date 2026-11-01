import 'package:better_phenikaa_schedule/features/qldt_intake/qldt_webview.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) {
        return const BootstrapScreen();
      },
    ),
    GoRoute(
      path: '/qldt',
      builder: (context, state) => const QldtWebViewPage(
        portalUrl: 'https://qldtbeta.phenikaa-uni.edu.vn/',
      ),
    ),
  ],
);

class BetterPhenikaaScheduleApp extends StatelessWidget {
  const new({super.key});

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

class BootstrapScreen extends StatelessWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Better Phenikaa Schedule',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bản thử kết nối và lấy lịch QLĐT.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.go('/qldt'),
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Đăng nhập QLĐT'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
