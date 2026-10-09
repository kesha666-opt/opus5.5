"""The shipped key-only UI: no real credentials or provider calls."""

import json
from pathlib import Path

from playwright.sync_api import Page, expect

STATIC = Path(__file__).resolve().parents[1] / "src/free_claude_code/api/admin_static"
URL = "http://127.0.0.1:18283/admin"


def panel(page: Page, *, configured=False, failure=None):
    calls = []

    def route(request):
        path = request.request.url.split("18283", 1)[1]
        if path.startswith("/admin/assets/"):
            name = path.split("/test/", 1)[1]
            file = STATIC / name
            request.fulfill(path=str(file))
        elif path == "/admin/api/config":
            request.fulfill(
                json={
                    "fields": [
                        {
                            "key": "NVIDIA_NIM_API_KEY",
                            "configured": configured,
                            "locked": False,
                        }
                    ]
                }
            )
        elif path.startswith("/admin/api/opus/"):
            calls.append(request.request)
            request.fulfill(json=failure or {"ok": True})
        else:
            request.fulfill(
                body=(STATIC / "index.html")
                .read_text(encoding="utf-8")
                .replace("__FCC_VERSION__", "test"),
                content_type="text/html",
            )

    page.route("http://127.0.0.1:18283/**", route)
    page.goto(URL)
    expect(page.locator("#apiKey")).to_be_enabled()
    return calls


def test_load_never_spends_a_provider_request(page):
    calls = panel(page, configured=True)
    expect(page.locator("#statusText")).to_contain_text("Key saved")
    assert calls == []
    page.locator("#saveButton").click()
    expect(page.locator("#status")).to_have_class("status ok")
    assert len(calls) == 1
    assert calls[0].url.endswith("/verify")


def test_success_masks_and_clears_key_without_url_leak(page):
    calls = panel(page)
    secret = "nvapi-" + "synthetic-test-key"
    page.locator("#apiKey").fill(secret)
    expect(page.locator("#apiKey")).to_have_attribute("type", "password")
    page.locator("#toggleKey").click()
    expect(page.locator("#apiKey")).to_have_attribute("type", "text")
    page.locator("#saveButton").click()
    expect(page.locator("#status")).to_have_class("status ok")
    expect(page.locator("#apiKey")).to_have_value("")
    expect(page.locator("#apiKey")).to_have_attribute("type", "password")
    expect(page.locator("#toggleKey")).to_have_attribute("aria-label", "Show key")
    assert len(calls) == 1 and calls[0].method == "POST"
    assert json.loads(calls[0].post_data) == {"api_key": secret}
    assert page.url == URL
    assert secret not in page.content()


def test_failure_preserves_key_and_does_not_light_green(page):
    panel(page, failure={"ok": False, "message": "NVIDIA temporarily unavailable."})
    page.locator("#apiKey").fill("synthetic-test-key")
    page.locator("#saveButton").click()
    expect(page.locator("#status")).to_have_class("status error")
    expect(page.locator("#apiKey")).to_have_value("synthetic-test-key")
    expect(page.locator("#saveButton")).to_be_enabled()
    assert page.url == URL


def test_network_failure_is_actionable(page):
    panel(page)
    page.route("**/admin/api/opus/configure", lambda route: route.abort())
    page.locator("#apiKey").fill("synthetic-test-key")
    page.locator("#saveButton").click()
    expect(page.locator("#statusText")).to_contain_text("fcc-server")
    expect(page.locator("#apiKey")).to_have_value("synthetic-test-key")


def test_no_script_cannot_submit_key_in_url(browser):
    context = browser.new_context(java_script_enabled=False)
    try:
        page = context.new_page()
        page.route(
            "**/*",
            lambda route: route.fulfill(
                body=(STATIC / "index.html").read_text(encoding="utf-8"),
                content_type="text/html",
            ),
        )
        page.goto(URL)
        expect(page.locator("#apiKey")).to_be_disabled()
        expect(page.locator("#saveButton")).to_be_disabled()
        expect(page.locator("#keyForm")).to_have_attribute("method", "post")
        assert page.locator("#apiKey").get_attribute("name") is None
    finally:
        context.close()


def test_phone_layout_has_no_horizontal_overflow(page):
    page.set_viewport_size({"width": 375, "height": 812})
    panel(page)
    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
    expect(page.locator("#saveButton")).to_be_in_viewport()


def test_editing_key_resets_previous_green_status(page):
    panel(page)
    page.locator("#apiKey").fill("synthetic-key")
    page.locator("#saveButton").click()
    expect(page.locator("#status")).to_have_class("status ok")
    expect(page.locator("#statusText")).to_contain_text("fcc-server")
    expect(page.locator("#statusText")).to_contain_text("fcc-opus")
    page.locator("#apiKey").fill("different-key")
    expect(page.locator("#status")).to_have_class("status neutral")
