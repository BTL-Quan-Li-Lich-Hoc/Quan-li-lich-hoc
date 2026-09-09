import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to the bootstrap screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BetterPhenikaaScheduleApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Better Phenikaa Schedule'), findsOneWidget);
  });
}
