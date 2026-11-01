import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login_mobile.dart'
    as mobile;
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login_result.dart';
import 'package:better_phenikaa_schedule/features/tro_li/assistant_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'missing callback ends loading and retry reads TraCuu without DOM',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final response = jsonEncode(<String, Object>{
        'Success': true,
        'Data': <Map<String, Object>>[
          <String, Object>{
            'PHANLOAI': 'LICHHOC',
            'TENHOCPHAN': 'Thiết kế web nâng cao',
            'TENLOPHOCPHAN': 'WEB-2026-LT',
            'NGAYHOC': '23/09/2026',
            'GIOBATDAU': 7,
            'PHUTBATDAU': 0,
            'GIOKETTHUC': 9,
            'PHUTKETTHUC': 0,
            'PHONGHOC_TEN': 'A1',
          },
        ],
      });
      final semesters = jsonEncode(<String, Object>{
        'Success': true,
        'Data': <Map<String, String>>[
          <String, String>{'ID': 'old', 'THOIGIAN': '2025_2026_3'},
          <String, String>{'ID': 'new', 'THOIGIAN': '2026_2027_1'},
        ],
      });
      final plans = jsonEncode(<String, Object>{
        'Success': true,
        'Data': <Map<String, String>>[
          <String, String>{
            'ID': 'new-plan',
            'DAOTAO_THOIGIANDAOTAO_ID': 'new',
            'MAKEHOACH': '2026_2027_1,1',
          },
        ],
      });
      final registrations = jsonEncode(<String, Object>{
        'Success': true,
        'Data': <Map<String, String>>[
          <String, String>{
            'DANGKY_KEHOACHDANGKY_ID': 'new-plan',
            'DAOTAO_THOIGIANDAOTAO_ID': 'new',
            'DAOTAO_HOCPHAN_ID': 'web',
            'DAOTAO_HOCPHAN_TEN': 'Thiết kế web nâng cao',
            'DANGKY_LOPHOCPHAN_ID': 'web-lt',
            'DANGKY_LOPHOCPHAN_TEN': 'WEB-2026-LT',
            'NGAYBATDAU': '17/08/2026',
            'NGAYKETTHUC': '01/11/2026',
          },
        ],
      });
      final retryAfterMillis = DateTime.now()
          .add(const Duration(seconds: 46))
          .millisecondsSinceEpoch;
      final html =
          '''
      <!doctype html><html><body>
      <script>
        window.edu = {system: {userId: 'fixture', iM: 1,
          makeRequest: function (options) {
            if (options.data.func ===
                'pkg_congthongtin_hssv_thongtin.LayDSLichCaNhan' &&
                Date.now() < $retryAfterMillis) {
              return;
            }
            switch (options.data.func) {
              case 'pkg_congthongtin_hssv_thongtin.LayDSLichCaNhan':
                options.success($response); break;
              case 'pkg_dangkyhoc_thongtin.LayThoiGianDangKyCaNhan':
                options.success($semesters); break;
              case 'pkg_dangkyhoc_thongtin.LayDSKeHoachDangKyCaNhan':
                options.success($plans); break;
              case 'pkg_dangkyhoc_chung.LayKetQuaDangKyLopHocPhan':
                options.success($registrations); break;
              default: options.error();
            }
          }
        }};
      </script>
      </body></html>
    ''';
      QldtLoginResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await mobile.openQldtLogin(context, testHtml: html);
                },
                child: const Text('Mở QLĐT giả lập'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở QLĐT giả lập'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 48)),
      );
      await tester.pump();
      expect(
        find.text(
          AssistantText.of(AssistantEvent.syncTimeout, AssistantPack.normal),
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Thử đồng bộ lại'), findsOneWidget);
      expect(result, isNull);

      await tester.tap(find.text('Thử đồng bộ lại'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 8)),
      );
      await tester.pump();
      final labels = find
          .byType(Text)
          .evaluate()
          .map((element) => (element.widget as Text).data)
          .join(' | ');
      expect(
        result?.semester?.subjects.single.name,
        'Thiết kế web nâng cao',
        reason: labels,
      );
    },
  );
}
