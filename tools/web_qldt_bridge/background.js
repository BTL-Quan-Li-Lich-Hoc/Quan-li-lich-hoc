const QLDT_PATTERN = 'https://qldtbeta.phenikaa-uni.edu.vn/*';
const QLDT_HOME = 'https://qldtbeta.phenikaa-uni.edu.vn/';
const FLOW_KEY = 'betterPhenikaaAutoLoginFlowV1';
const ATTEMPT_DELAYS_MS = [0, 500, 1000, 1500, 2500, 4000];

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (!message || typeof message.type !== 'string') {
    return false;
  }

  if (message.type === 'betterPhenikaaStartAutoLogin') {
    startAutoLogin(message.start, message.end, sender.tab?.id)
      .then(sendResponse)
      .catch((error) => {
        sendResponse({
          ok: false,
          code: 'bridge_error',
          message: `Không thể bắt đầu đăng nhập QLĐT: ${String(error)}`,
        });
      });
    return true;
  }

  if (message.type === 'betterPhenikaaCancelAutoLogin') {
    cancelAutoLogin(sender.tab?.id)
      .then(() => sendResponse({ ok: true }))
      .catch((error) => {
        sendResponse({
          ok: false,
          code: 'cancel_failed',
          message: String(error),
        });
      });
    return true;
  }

  return false;
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === 'complete' || changeInfo.url) {
    void maybeCompleteAutoLogin(tabId);
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  void handleRemovedTab(tabId);
});

async function startAutoLogin(start, end, appTabId) {
  if (appTabId == null) {
    return {
      ok: false,
      code: 'missing_app_tab',
      message: 'Không xác định được tab Better Phenikaa App.',
    };
  }

  const previous = await getFlow();
  if (previous?.qldtTabId != null) {
    await safeRemoveTab(previous.qldtTabId);
  }

  const tabs = await chrome.tabs.query({ url: QLDT_PATTERN });
  let qldtTab = tabs.find((item) => item.id != null);

  if (qldtTab?.id != null) {
    await chrome.tabs.update(qldtTab.id, { active: true });
  } else {
    qldtTab = await chrome.tabs.create({ url: QLDT_HOME, active: true });
  }

  if (qldtTab.id == null) {
    return {
      ok: false,
      code: 'qldt_tab_failed',
      message: 'Không mở được tab QLĐT beta.',
    };
  }

  const flow = {
    appTabId,
    qldtTabId: qldtTab.id,
    start: String(start || ''),
    end: String(end || ''),
    startedAt: Date.now(),
  };
  await chrome.storage.session.set({ [FLOW_KEY]: flow });

  void attemptUntilReady(flow);
  return { ok: true, started: true };
}

async function cancelAutoLogin(appTabId) {
  const flow = await getFlow();
  if (!flow) {
    return;
  }
  if (appTabId != null && flow.appTabId !== appTabId) {
    return;
  }

  await chrome.storage.session.remove(FLOW_KEY);
  await safeRemoveTab(flow.qldtTabId);
  await safeActivateTab(flow.appTabId);
}

async function maybeCompleteAutoLogin(tabId) {
  const flow = await getFlow();
  if (!flow || flow.qldtTabId !== tabId) {
    return;
  }
  await attemptUntilReady(flow);
}

async function attemptUntilReady(flow) {
  for (const delayMs of ATTEMPT_DELAYS_MS) {
    if (delayMs > 0) {
      await sleep(delayMs);
    }

    const current = await getFlow();
    if (!current || current.qldtTabId !== flow.qldtTabId) {
      return;
    }

    let result;
    try {
      result = await readScheduleFromQldtTab(
        current.qldtTabId,
        current.start,
        current.end,
      );
    } catch (_) {
      continue;
    }

    if (!result || typeof result !== 'object') {
      continue;
    }

    if (result.ok) {
      await finishSuccess(current, result);
      return;
    }

    if (result.code !== 'login_required' && result.code !== 'empty_result') {
      await finishError(current, result);
      return;
    }
  }
}

async function finishSuccess(flow, result) {
  await chrome.storage.session.remove(FLOW_KEY);
  await sendToApp(flow.appTabId, {
    type: 'betterPhenikaaAutoLoginResult',
    response: result,
  });
  await safeRemoveTab(flow.qldtTabId);
  await safeActivateTab(flow.appTabId);
}

async function finishError(flow, result) {
  await chrome.storage.session.remove(FLOW_KEY);
  await sendToApp(flow.appTabId, {
    type: 'betterPhenikaaAutoLoginError',
    response: result,
  });
  await safeActivateTab(flow.appTabId);
}

async function handleRemovedTab(tabId) {
  const flow = await getFlow();
  if (!flow || flow.qldtTabId !== tabId) {
    return;
  }

  await chrome.storage.session.remove(FLOW_KEY);
  await sendToApp(flow.appTabId, {
    type: 'betterPhenikaaAutoLoginError',
    response: {
      ok: false,
      code: 'login_cancelled',
      message: 'Tab QLĐT đã bị đóng trước khi đồng bộ hoàn tất.',
    },
  });
  await safeActivateTab(flow.appTabId);
}

async function getFlow() {
  const stored = await chrome.storage.session.get(FLOW_KEY);
  return stored?.[FLOW_KEY] || null;
}

async function sendToApp(appTabId, message) {
  try {
    await chrome.tabs.sendMessage(appTabId, message);
  } catch (_) {
    // The app tab may have been closed or reloaded.
  }
}

async function safeRemoveTab(tabId) {
  if (tabId == null) {
    return;
  }
  try {
    await chrome.tabs.remove(tabId);
  } catch (_) {
    // Tab is already gone.
  }
}

async function safeActivateTab(tabId) {
  if (tabId == null) {
    return;
  }
  try {
    await chrome.tabs.update(tabId, { active: true });
  } catch (_) {
    // App tab may have been closed.
  }
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function readScheduleFromQldtTab(tabId, start, end) {
  const [{ result } = {}] = await chrome.scripting.executeScript({
    target: { tabId },
    world: 'MAIN',
    func: readQldtSchedule,
    args: [String(start || ''), String(end || '')],
  });

  if (!result || typeof result !== 'object') {
    return {
      ok: false,
      code: 'empty_result',
      message: 'Tab QLĐT chưa trả kết quả đồng bộ.',
    };
  }
  return result;
}

function readQldtSchedule(start, end) {
  return new Promise((resolve) => {
    try {
      if (
        !(
          window.edu &&
          edu.system &&
          edu.system.userId &&
          edu.system.iM != null &&
          typeof edu.system.makeRequest === 'function'
        )
      ) {
        resolve({
          ok: false,
          code: 'login_required',
          message:
            'Phiên QLĐT chưa sẵn sàng. Hãy hoàn tất đăng nhập Microsoft và chờ trang QLĐT tải xong.',
        });
        return;
      }

      const requestData = {
        action: 'SV_ThongTin_MH/DSA4BRINKCIpAiAPKSAv',
        func: 'pkg_congthongtin_hssv_thongtin.LayDSLichCaNhan',
        iM: edu.system.iM,
        strQLSV_NguoiHoc_Id: edu.system.userId,
        strNgayBatDau: start,
        strNgayKetThuc: end,
      };

      edu.system.makeRequest(
        {
          success(response) {
            let name = '';
            const preferred = document.querySelector('#lblHoTenNguoiDangNhap');
            if (preferred) {
              name = String(preferred.textContent || '').trim();
            }
            if (!name) {
              const spans = document.querySelectorAll('.nav-account button > span');
              for (const span of spans) {
                const candidate = String(span.textContent || '').trim();
                if (candidate) {
                  name = candidate;
                  break;
                }
              }
            }

            resolve({
              ok: true,
              envelope: JSON.stringify({ name, response }),
            });
          },
          error() {
            resolve({
              ok: false,
              code: 'qldt_request_failed',
              message:
                'QLĐT không trả dữ liệu lịch. Hãy tải lại trang QLĐT rồi thử lại.',
            });
          },
          type: 'POST',
          action: requestData.action,
          contentType: true,
          data: requestData,
          fakedb: [],
        },
        false,
        false,
        false,
        null,
      );
    } catch (error) {
      resolve({
        ok: false,
        code: 'page_script_error',
        message: `Không đọc được phiên QLĐT: ${String(error)}`,
      });
    }
  });
}
