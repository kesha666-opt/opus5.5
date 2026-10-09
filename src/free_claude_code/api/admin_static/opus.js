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
      ? "NVIDIA is taking too long to respond. Your key is still in the field. Please try again later."
      : "Cannot connect to the server. Run fcc-server and open http://127.0.0.1:8182/admin.");
  }
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.detail || `HTTP error ${response.status}`);
  return payload;
}

function safeMessage(value, fallback) {
  if (typeof value !== "string" || !value.trim()) return fallback;
  return value.replace(/nvapi-[A-Za-z0-9_-]+/g, "[key hidden]");
}

async function verifyProvider() {
  setStatus("neutral", "Claude Code Chat Opus 5.5", "Checking the connection to NVIDIA…");
  const result = await request("/admin/api/opus/verify", { method: "POST", body: "{}" });
  if (!result.ok) throw new Error(result.message || "NVIDIA rejected the request.");
  setStatus("ok", "Claude Code Chat Opus 5.5", "Connection verified. First terminal: fcc-server. Second terminal: fcc-opus.");
}

async function loadState() {
  try {
    const config = await request("/admin/api/config");
    const fields = new Map(config.fields.map((field) => [field.key, field]));
    const key = fields.get("NVIDIA_NIM_API_KEY");
    if (key?.locked) {
      setBusy(true);
      setStatus("error", "Settings locked", "The key is set through an environment variable. Remove it and restart Opus 5.5 to change the key here.");
    } else {
      keyConfigured = Boolean(key?.configured);
      if (keyConfigured) {
        keyInput.placeholder = "Key saved — enter a new key to replace it";
        setStatus("neutral", "Claude Code Chat Opus 5.5", "Key saved. Use the button below to check the connection.");
      }
      setBusy(false);
    }
  } catch (error) {
    setStatus("error", "Panel unavailable", safeMessage(error.message, "Could not load settings."));
  }
}

toggleKey.addEventListener("click", () => {
  const reveal = keyInput.type === "password";
  keyInput.type = reveal ? "text" : "password";
  toggleKey.setAttribute("aria-label", reveal ? "Hide key" : "Show key");
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
    setStatus("error", "API key required", "Paste your NVIDIA API key.");
    keyInput.focus();
    return;
  }
  setBusy(true);
  setStatus("neutral", "Claude Code Chat Opus 5.5", "Checking your key and connection to NVIDIA…");
  try {
    if (!apiKey) { await verifyProvider(); return; }
    const result = await request("/admin/api/opus/configure", {
      method: "POST",
      body: JSON.stringify({ api_key: apiKey }),
    });
    if (!result.ok) throw new Error(result.message || "The key was not accepted.");
    keyConfigured = true;
    keyInput.value = "";
    keyInput.type = "password";
    toggleKey.setAttribute("aria-label", "Show key");
    updateClearButton();
    keyInput.placeholder = "Key saved — enter a new key to replace it";
    setStatus("ok", "Claude Code Chat Opus 5.5", "Key verified and saved. First terminal: fcc-server. Second terminal: fcc-opus.");
  } catch (error) {
    setStatus("error", "Could not save key", safeMessage(error.message, "Check your key and try again."));
  } finally {
    setBusy(false);
  }
});

loadState();
