const keyInput = document.querySelector("#apiKey");
const form = document.querySelector("#keyForm");
const saveButton = document.querySelector("#saveButton");
const toggleKey = document.querySelector("#toggleKey");
const statusBox = document.querySelector("#status");
const statusTitle = document.querySelector("#statusTitle");
const statusText = document.querySelector("#statusText");
const nextStep = document.querySelector("#nextStep");

function setStatus(kind, title, text) {
  statusBox.className = `status ${kind}`;
  statusTitle.textContent = title;
  statusText.textContent = text;
  nextStep.hidden = kind !== "ok";
}

async function request(path, options = {}) {
  const response = await fetch(path, { cache: "no-store", headers: { "Content-Type": "application/json", ...(options.headers || {}) }, ...options });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.detail || `Ошибка HTTP ${response.status}`);
  return payload;
}

function safeMessage(value, fallback) {
  if (typeof value !== "string" || !value.trim()) return fallback;
  return value.replace(/nvapi-[A-Za-z0-9_-]+/g, "[ключ скрыт]");
}

async function verifyProvider() {
  setStatus("neutral", "Проверяем NVIDIA…", "Выполняется реальный запрос списка доступных моделей.");
  try {
    const result = await request("/admin/api/nova/verify", { method: "POST", body: "{}" });
    if (!result.ok) throw new Error(result.message || "NVIDIA отклонила запрос.");
    setStatus("ok", "Подключение работает", "NVIDIA выполнила проверочный запрос. Можно запускать fcc-claude.");
  } catch (error) {
    setStatus("error", "Проверка не пройдена", safeMessage(error.message, "Проверьте ключ и подключение к интернету."));
  }
}

async function loadState() {
  try {
    const config = await request("/admin/api/config");
    const fields = new Map(config.fields.map((field) => [field.key, field]));
    const key = fields.get("NVIDIA_NIM_API_KEY");
    if (key?.locked) {
      keyInput.disabled = true; saveButton.disabled = true;
      setStatus("error", "Настройка заблокирована", "Ключ задан переменной окружения. Уберите её и перезапустите Nova Code.");
    } else if (key?.configured) {
      keyInput.placeholder = "Ключ сохранён — введите новый для замены";
      setStatus("neutral", "Ключ сохранён", "Проверяем текущее подключение.");
      await verifyProvider();
    } else {
      setStatus("neutral", "Нужен API‑ключ", "Введите ключ NVIDIA и запустите проверку.");
    }
  } catch (error) {
    setStatus("error", "Панель недоступна", safeMessage(error.message, "Не удалось загрузить настройки."));
  }
}

toggleKey.addEventListener("click", () => {
  const reveal = keyInput.type === "password";
  keyInput.type = reveal ? "text" : "password";
  toggleKey.textContent = reveal ? "Скрыть" : "Показать";
  toggleKey.setAttribute("aria-label", reveal ? "Скрыть ключ" : "Показать ключ");
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const apiKey = keyInput.value.trim();
  if (!apiKey) { setStatus("error", "Ключ не введён", "Вставьте API‑ключ NVIDIA."); keyInput.focus(); return; }
  saveButton.disabled = true; keyInput.disabled = true;
  setStatus("neutral", "Сохраняем и проверяем…", "Ключ остаётся в локальном файле настроек.");
  try {
    const result = await request("/admin/api/nova/configure", { method: "POST", body: JSON.stringify({ api_key: apiKey }) });
    keyInput.value = ""; keyInput.type = "password"; toggleKey.textContent = "Показать";
    if (!result.ok) {
      throw new Error(result.message || "Ключ не принят.");
    }
    keyInput.placeholder = "Ключ сохранён — введите новый для замены";
    setStatus("ok", "Подключение работает", "NVIDIA выполнила проверочный запрос. Можно запускать fcc-claude.");
  } catch (error) {
    keyInput.value = "";
    setStatus("error", "Не удалось сохранить", safeMessage(error.message, "Проверьте ключ и повторите попытку."));
  } finally {
    keyInput.disabled = false; saveButton.disabled = false;
  }
});

loadState();
