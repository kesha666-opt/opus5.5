const keyInput = document.querySelector("#apiKey");
const form = document.querySelector("#keyForm");
const saveButton = document.querySelector("#saveButton");
const toggleKey = document.querySelector("#toggleKey");
const clearKey = document.querySelector("#clearKey");
const statusBox = document.querySelector("#status");
const statusTitle = document.querySelector("#statusTitle");
const statusText = document.querySelector("#statusText");

function setStatus(kind, title, text) {
  statusBox.className = `status ${kind}`;
  statusTitle.textContent = title;
  statusText.textContent = text;
}

function updateClearButton() {
  clearKey.hidden = !keyInput.value;
}

async function request(path, options = {}) {
  const response = await fetch(path, {
    cache: "no-store",
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options,
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.detail || `Ошибка HTTP ${response.status}`);
  return payload;
}

function safeMessage(value, fallback) {
  if (typeof value !== "string" || !value.trim()) return fallback;
  return value.replace(/nvapi-[A-Za-z0-9_-]+/g, "[ключ скрыт]");
}

async function verifyProvider() {
  setStatus("neutral", "Проверяем NVIDIA API…", "Выполняется короткий проверочный запрос.");
  const result = await request("/admin/api/opus/verify", { method: "POST", body: "{}" });
  if (!result.ok) throw new Error(result.message || "NVIDIA отклонила запрос.");
  setStatus("ok", "NVIDIA API подключён", "Ключ проверен. Соединение установлено.");
}

async function loadState() {
  try {
    const config = await request("/admin/api/config");
    const fields = new Map(config.fields.map((field) => [field.key, field]));
    const key = fields.get("NVIDIA_NIM_API_KEY");
    if (key?.locked) {
      keyInput.disabled = true;
      saveButton.disabled = true;
      setStatus("error", "Настройка заблокирована", "Ключ задан переменной окружения. Уберите её и перезапустите Opus 5.5.");
    } else if (key?.configured) {
      keyInput.placeholder = "Ключ сохранён — введите новый для замены";
      try { await verifyProvider(); }
      catch (error) { setStatus("error", "Проверка не пройдена", safeMessage(error.message, "Проверьте ключ и подключение к интернету.")); }
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

keyInput.addEventListener("input", updateClearButton);

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const apiKey = keyInput.value.trim();
  if (!apiKey) {
    setStatus("error", "Ключ не введён", "Вставьте API‑ключ NVIDIA.");
    keyInput.focus();
    return;
  }
  saveButton.disabled = true;
  keyInput.disabled = true;
  setStatus("neutral", "Сохраняем и проверяем…", "Ключ остаётся только в локальных настройках.");
  try {
    const result = await request("/admin/api/opus/configure", {
      method: "POST",
      body: JSON.stringify({ api_key: apiKey }),
    });
    keyInput.value = "";
    keyInput.type = "password";
    updateClearButton();
    if (!result.ok) throw new Error(result.message || "Ключ не принят.");
    keyInput.placeholder = "Ключ сохранён — введите новый для замены";
    setStatus("ok", "NVIDIA API подключён", "Ключ проверен. Соединение установлено.");
  } catch (error) {
    keyInput.value = "";
    updateClearButton();
    setStatus("error", "Не удалось сохранить", safeMessage(error.message, "Проверьте ключ и повторите попытку."));
  } finally {
    keyInput.disabled = false;
    saveButton.disabled = false;
  }
});

loadState();
