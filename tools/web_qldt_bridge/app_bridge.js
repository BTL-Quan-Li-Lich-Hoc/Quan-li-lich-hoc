(() => {
  const START_EVENT = 'better-phenikaa-start-qldt-login';
  const CANCEL_EVENT = 'better-phenikaa-cancel-qldt-login';
  const RESULT_EVENT = 'better-phenikaa-qldt-result';
  const ERROR_EVENT = 'better-phenikaa-qldt-error';

  const markReady = () => {
    if (!document.documentElement) {
      return false;
    }
    document.documentElement.dataset.betterPhenikaaBridge = 'ready';
    window.dispatchEvent(new CustomEvent('better-phenikaa-bridge-ready'));
    return true;
  };

  if (!markReady()) {
    document.addEventListener('DOMContentLoaded', markReady, { once: true });
  }

  window.addEventListener(START_EVENT, async (event) => {
    let payload = {};
    try {
      payload = JSON.parse(String(event.detail || '{}'));
    } catch (_) {
      emitError('Yêu cầu đăng nhập web không hợp lệ.', 'bad_payload');
      return;
    }

    try {
      const response = await chrome.runtime.sendMessage({
        type: 'betterPhenikaaStartAutoLogin',
        start: payload.start,
        end: payload.end,
      });
      if (!response?.ok) {
        emitError(
          response?.message || 'Không thể mở phiên đăng nhập QLĐT.',
          response?.code,
        );
      }
    } catch (error) {
      emitError(`Web Bridge gặp lỗi: ${String(error)}`, 'bridge_error');
    }
  });

  window.addEventListener(CANCEL_EVENT, () => {
    void chrome.runtime.sendMessage({ type: 'betterPhenikaaCancelAutoLogin' });
  });

  chrome.runtime.onMessage.addListener((message) => {
    if (!message || typeof message.type !== 'string') {
      return false;
    }

    if (message.type === 'betterPhenikaaAutoLoginResult') {
      window.dispatchEvent(
        new CustomEvent(RESULT_EVENT, {
          detail: JSON.stringify(message.response || {}),
        }),
      );
      return false;
    }

    if (message.type === 'betterPhenikaaAutoLoginError') {
      emitError(
        message.response?.message || 'Không thể đồng bộ QLĐT.',
        message.response?.code,
      );
    }
    return false;
  });

  function emitError(message, code) {
    window.dispatchEvent(
      new CustomEvent(ERROR_EVENT, {
        detail: JSON.stringify({ message, code }),
      }),
    );
  }
})();
