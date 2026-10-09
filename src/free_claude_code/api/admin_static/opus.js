const keyInput = document.querySelector("#apiKey");
const form = document.querySelector("#keyForm");
const saveButton = document.querySelector("#saveButton");
const toggleKey = document.querySelector("#toggleKey");
const clearKey = document.querySelector("#clearKey");
const statusBox = document.querySelector("#status");
const statusTitle = document.querySelector("#statusTitle");
const statusText = document.querySelector("#statusText");
let keyConfigured = false;
let busy = true;

function setBusy(value) {
  busy = value;
  form.setAttribute("aria-busy", String(value));
  for (const control of [keyInput, saveButton, toggleKey, clearKey]) control.disabled = value;
}

function setStatus(kind, title, text) {
  statusBox.className = `status ${kind}`;
  statusTitle.textContent = title;
  statusText.textContent = text || "";
  statusText.hidden = !text;
}

function updateClearButton() {
  clearKey.hidden = !keyInput.value;
}

async function request(path, options = {}) {
  let response;
  try { response = await fetch(path, {
    ...options,
    cache: "no-store",
    signal: AbortSignal.timeout(135000),
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
  }); } catch (error) {
    throw new Error(error.name === "TimeoutError"
      ? "NVIDIA отвечает слишком долго. Ключ оставлен в поле — повторите попытку позже."
      : "Нет связи с сервером. Запустите fcc-server и откройте http://127.0.0.1:8182/admin.");
  }
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.detail || `Ошибка HTTP ${response.status}`);
  return payload;
}

function safeMessage(value, fallback) {
  if (typeof value !== "string" || !value.trim()) return fallback;
  return value.replace(/nvapi-[A-Za-z0-9_-]+/g, "[ключ скрыт]");
}

async function verifyProvider() {
  setStatus("neutral", "Claude Code Chat Opus 5.5", "Проверяем подключение к NVIDIA…");
  const result = await request("/admin/api/opus/verify", { method: "POST", body: "{}" });
  if (!result.ok) throw new Error(result.message || "NVIDIA отклонила запрос.");
  setStatus("ok", "Claude Code Chat Opus 5.5", "Подключение проверено. Первый терминал: fcc-server. Второй: fcc-opus.");
}

async function loadState() {
  try {
    const config = await request("/admin/api/config");
    const fields = new Map(config.fields.map((field) => [field.key, field]));
    const key = fields.get("NVIDIA_NIM_API_KEY");
    if (key?.locked) {
      setBusy(true);
      setStatus("error", "Настройка заблокирована", "Ключ задан переменной окружения. Уберите её и перезапустите Opus 5.5.");
    } else {
      keyConfigured = Boolean(key?.configured);
      if (keyConfigured) {
        keyInput.placeholder = "Ключ сохранён — введите новый для замены";
        setStatus("neutral", "Claude Code Chat Opus 5.5", "Ключ сохранён. Кнопка ниже проверит подключение.");
      }
      setBusy(false);
    }
  } catch (error) {
    setStatus("error", "Панель недоступна", safeMessage(error.message, "Не удалось загрузить настройки."));
  }
}

toggleKey.addEventListener("click", () => {
  const reveal = keyInput.type === "password";
  keyInput.type = reveal ? "text" : "password";
  toggleKey.setAttribute("aria-label", reveal ? "Скрыть ключ" : "Показать ключ");
});

clearKey.addEventListener("click", () => {
  keyInput.value = "";
  updateClearButton();
  keyInput.focus();
});

keyInput.addEventListener("input", () => {
  updateClearButton();
  setStatus("neutral", "Claude Code Chat Opus 5.5");
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (busy) return;
  const apiKey = keyInput.value.trim();
  if (!apiKey && !keyConfigured) {
    setStatus("error", "Ключ не введён", "Вставьте API‑ключ NVIDIA.");
    keyInput.focus();
    return;
  }
  setBusy(true);
  setStatus("neutral", "Claude Code Chat Opus 5.5", "Проверяем ключ и подключение к NVIDIA…");
  try {
    if (!apiKey) { await verifyProvider(); return; }
    const result = await request("/admin/api/opus/configure", {
      method: "POST",
      body: JSON.stringify({ api_key: apiKey }),
    });
    if (!result.ok) throw new Error(result.message || "Ключ не принят.");
    keyConfigured = true;
    keyInput.value = "";
    keyInput.type = "password";
    toggleKey.setAttribute("aria-label", "Показать ключ");
    updateClearButton();
    keyInput.placeholder = "Ключ сохранён — введите новый для замены";
    setStatus("ok", "Claude Code Chat Opus 5.5", "Ключ проверен и сохранён. Первый терминал: fcc-server. Второй: fcc-opus.");
  } catch (error) {
    setStatus("error", "Не удалось сохранить", safeMessage(error.message, "Проверьте ключ и повторите попытку."));
  } finally {
    setBusy(false);
  }
});

loadState();
