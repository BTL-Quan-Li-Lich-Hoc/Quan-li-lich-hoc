import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app opens timetable with day and week views', (tester) async {
    await tester.pumpWidget(
      const BetterPhenikaaScheduleApp(initializeLocalData: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lịch học'), findsWidgets);
    expect(find.text('Lịch thi'), findsOneWidget);
    expect(find.text('Ngày'), findsOneWidget);
    expect(find.text('Tuần'), findsOneWidget);
    expect(find.text('Chưa có lịch học'), findsOneWidget);

    await tester.tap(find.text('Tuần'));
    await tester.pumpAndSettle();

    expect(find.textContaining(' – '), findsOneWidget);
    expect(find.text('Không có buổi học trong tuần đã chọn.'), findsOneWidget);
  });
}
