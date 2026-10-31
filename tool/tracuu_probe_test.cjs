const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname,
  '../lib/features/dang_nhap_qldt/tracuu_webview_probe.dart'), 'utf8');
const script = source.match(/String get _script => r'''([\s\S]*?)'''/)[1]
  .replaceAll('__BP_ATTEMPT__', '7');

async function run({selected = false, delayedPlan = false, networkFailure = false} = {}) {
  const calls = [];
  let clickCount = 0;
  let changed = () => {};
  let loaded = selected;
  const option = (value, name) => ({value, textContent: name});
  const semester = {
    value: selected ? 'new' : 'old',
    options: [option('old', '2025_2026_3'), option('new', '2026_2027_1')],
    dispatchEvent() {
      if (delayedPlan) queueMicrotask(() => { plan.options = [
        option('new-plan', '2026_2027_1,1 Đăng ký HK1')
      ]; });
    },
  };
  const plan = {
    value: selected ? 'new-plan' : '',
    options: delayedPlan ? [] : [option('new-plan', '2026_2027_1,1 Đăng ký HK1')],
    dispatchEvent() {},
  };
  const results = {
    get innerHTML() { return loaded ? '<div class="subject-item">Môn học</div>' : ''; },
    querySelector(selector) { return selector === '.subject-item' && loaded ? {} : null; },
  };
  const view = {
    click() {
      clickCount++;
      if (!networkFailure) {
        loaded = true;
        changed();
      }
    },
  };
  const nodes = {
    '#dropSearch_HocKy': semester,
    '#dropSearch_KeHoach': plan,
    '#zoneKetQuaDangKy': results,
    '#btnXemKetQuaDangKy': view,
  };
  const document = {
    querySelector: selector => nodes[selector],
    documentElement: {outerHTML: '<html>verified fixture</html>'},
  };
  const window = {flutter_inappwebview: {
    callHandler: (name, value) => calls.push({name, value}),
  }};
  class MutationObserver {
    constructor(callback) { this.callback = callback; }
    observe() { changed = this.callback; }
    disconnect() { changed = () => {}; }
  }
  await vm.runInNewContext(script, {
    document, window, MutationObserver,
    Event: class { constructor() {} },
    setTimeout: callback => queueMicrotask(callback),
  });
  return {calls, clickCount};
}

test('uses already loaded latest registration without another request', async () => {
  const result = await run({selected: true});
  assert.equal(result.clickCount, 0);
  assert.equal(result.calls.at(-1).name, 'betterPhenikaaRegistrationResult');
});

test('waits for asynchronous plan and real result mutation', async () => {
  const result = await run({delayedPlan: true});
  assert.equal(result.clickCount, 1);
  assert.equal(result.calls.at(-1).name, 'betterPhenikaaRegistrationResult');
});

test('network failure cannot reuse stale registration', async () => {
  const result = await run({networkFailure: true});
  assert.equal(result.clickCount, 1);
  assert.equal(result.calls.at(-1).name, 'betterPhenikaaRegistrationError');
});
