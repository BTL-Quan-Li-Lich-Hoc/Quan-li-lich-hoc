import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/registration_parser.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';

final class TracuuWebViewProbe {
  const new();

  RegisteredSemester parseResult(String raw) {
    final result = jsonDecode(raw) as Map<String, dynamic>;
    return const QldtRegistrationParser().parse(
      html: result['html'] as String,
      selectedSemesterValue: result['semester'] as String,
      selectedPlanValue: result['plan'] as String,
    );
  }

  String get script => scriptForAttempt(0);

  String scriptForAttempt(int attempt) =>
      _script.replaceAll('__BP_ATTEMPT__', '$attempt');

  String get _script => r'''
    (async function () {
      const sendStage = stage => window.flutter_inappwebview.callHandler(
        'betterPhenikaaRegistrationStage', __BP_ATTEMPT__, stage
      );
      const sendError = message => window.flutter_inappwebview.callHandler(
        'betterPhenikaaRegistrationError', __BP_ATTEMPT__, message
      );
      const waitFor = async predicate => {
        for (let attempt = 0; attempt < 300; attempt++) {
          const value = predicate();
          if (value) return value;
          await new Promise(resolve => setTimeout(resolve, 100));
        }
        throw Error('TraCuu chưa tải xong. Hãy thử đồng bộ lại.');
      };
      try {
        const semester = document.querySelector('#dropSearch_HocKy');
        const plan = document.querySelector('#dropSearch_KeHoach');
        const results = document.querySelector('#zoneKetQuaDangKy');
        const view = document.querySelector('#btnXemKetQuaDangKy');
        if (!semester || !plan || !results || !view) {
          throw Error('Trang TraCuu chưa sẵn sàng.');
        }
        const options = [...semester.options].map(option => {
          const name = option.textContent.trim();
          const match = /^(\d{4})_(\d{4})_(\d+)$/.exec(name);
          return match && Number(match[2]) === Number(match[1]) + 1 && option.value
            ? {value: option.value, name, year: Number(match[1]), term: Number(match[3])}
            : null;
        }).filter(Boolean).sort((a, b) => b.year - a.year || b.term - a.term);
        if (!options.length) throw Error('TraCuu chưa có học kỳ hợp lệ.');
        const latest = options[0];
        const initialSemester = semester.value;
        const initialPlan = plan.value;
        semester.value = latest.value;
        semester.dispatchEvent(new Event('change', {bubbles: true}));
        const matchingPlans = await waitFor(() => {
          const choices = [...plan.options].filter(option =>
            option.value && (option.textContent.trim() === latest.name ||
              option.textContent.trim().startsWith(latest.name + ','))
          );
          return choices.length ? choices : null;
        });
        if (matchingPlans.length !== 1) {
          throw Error('Không xác định được một kế hoạch đăng ký duy nhất.');
        }
        const matchingPlan = matchingPlans[0];
        plan.value = matchingPlan.value;
        plan.dispatchEvent(new Event('change', {bubbles: true}));
        sendStage('subjects');
        const alreadySelected = initialSemester === latest.value &&
          initialPlan === matchingPlan.value;
        const existing = alreadySelected && results.querySelector('.subject-item');
        if (!existing) {
          let changed = false;
          const observer = new MutationObserver(() => { changed = true; });
          observer.observe(results, {childList: true, subtree: true, characterData: true});
          try {
            view.click();
            await waitFor(() => changed && results.querySelector('.subject-item'));
          } finally {
            observer.disconnect();
          }
        }
        let previous = '';
        let stable = 0;
        await waitFor(() => {
          const current = results.innerHTML;
          stable = current === previous ? stable + 1 : 0;
          previous = current;
          return stable >= 4;
        });
        if (semester.value !== latest.value || plan.value !== matchingPlan.value) {
          throw Error('TraCuu đã đổi học kỳ hoặc kế hoạch trong lúc tải.');
        }
        sendStage('verification');
        window.flutter_inappwebview.callHandler(
          'betterPhenikaaRegistrationResult',
          __BP_ATTEMPT__,
          JSON.stringify({html: document.documentElement.outerHTML,
            semester: semester.value, plan: plan.value})
        );
      } catch (error) {
        sendError(error.message || 'Không xác minh được dữ liệu TraCuu.');
      }
    })();
  ''';
}
