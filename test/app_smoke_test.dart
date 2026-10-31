import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('integrated shell opens real day/week schedule view', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      const ProviderScope(child: BetterPhenikaaScheduleApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Lịch học'), findsWidgets);
    expect(find.text('Lịch thi'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('Khung lịch học'), findsNothing);
    expect(find.text('Ngày'), findsOneWidget);
    expect(find.text('Tuần'), findsOneWidget);
  });
}
