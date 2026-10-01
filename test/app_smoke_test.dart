import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to timetable shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BetterPhenikaaScheduleApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lịch học'), findsWidgets);
    expect(find.text('Lịch thi'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('Khung lịch học'), findsOneWidget);
  });
}
