import os
import re
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

import pytest
import yaml

UV_MINIMUM = "0.12.13"
CI_SETUP = Path(".github/actions/ci-environment/action.yml")
REQUIRED_TEST_RUNNERS = {
    "Linux": "ubuntu-latest",
    "Windows": "windows-latest",
    "macOS": "macos-latest",
}


@pytest.mark.parametrize(
    "requirement, valid",
    [
        ('"==3.14.7"', True),
        ("'==3.14.7'", True),
        ('"==3.14.7" # Python runtime', True),
        ('">=3.14.7"', False),
    ],
)
def test_ci_python_identity_parses_toml(
    tmp_path: Path, requirement: str, valid: bool
) -> None:
    setup = yaml.safe_load(CI_SETUP.read_text(encoding="utf-8"))
    step = next(step for step in setup["runs"]["steps"] if step.get("id") == "identity")
    (tmp_path / "pyproject.toml").write_text(
        f"[project]\nrequires-python = {requirement}\n", encoding="utf-8"
    )
    bash = shutil.which("bash")
    if sys.platform == "win32":
        git = shutil.which("git")
        assert git is not None
        bash = str(Path(git).resolve().parent.parent / "bin" / "bash.exe")
    assert bash is not None
    env = {
        **os.environ,
        "PATH": str(Path(sys.executable).parent) + os.pathsep + os.environ["PATH"],
        "CI_TEMP": tmp_path.as_posix(),
        "CI_RUNNER": "test-runner",
        "CI_OS": "test-os",
        "CI_ARCH": "X64",
        "CI_UV": UV_MINIMUM,
        "GITHUB_ENV": "github-env",
        "GITHUB_OUTPUT": "github-output",
    }
    result = subprocess.run(
        [bash, "-c", step["run"]],
        cwd=tmp_path,
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if valid:
        assert result.returncode == 0, result.stderr
        output = (tmp_path / "github-output").read_text(encoding="utf-8")
        assert "python-version=3.14.7\n" in output
        assert f"py-3.14.7-uv-{UV_MINIMUM}" in output
    else:
        assert result.returncode != 0
        assert not (tmp_path / "github-output").exists()


def test_installer_python_requests_match_package_requirement():
    project = tomllib.loads(Path("pyproject.toml").read_text(encoding="utf-8"))
    version = project["project"]["requires-python"].removeprefix("==")
    shell = Path("scripts/install.sh").read_text(encoding="utf-8")
    windows = Path("scripts/install.ps1").read_text(encoding="utf-8")
    assert f'PYTHON_VERSION="{version}"' in shell
    assert f'$PythonRequest = "{version}"' in windows
    assert '--python "$PYTHON_VERSION"' in shell
    assert "--python $PythonRequest" in windows
    assert (
        tomllib.loads(Path("uv.lock").read_text(encoding="utf-8"))["requires-python"]
        == f"=={version}"
    )


def test_supported_uv_minimum_is_consistent():
    project = tomllib.loads(Path("pyproject.toml").read_text(encoding="utf-8"))
    assert project["tool"]["uv"]["required-version"] == f">={UV_MINIMUM}"
    assert f'MIN_UV_VERSION="{UV_MINIMUM}"' in Path("scripts/install.sh").read_text(
        encoding="utf-8"
    )
    windows = Path("scripts/install.ps1").read_text(encoding="utf-8")
    pin = re.search(r'^\$PinnedUvVersion = "([0-9.]+)"$', windows, re.MULTILINE)
    assert pin is not None
    assert tuple(map(int, pin.group(1).split("."))) >= tuple(
        map(int, UV_MINIMUM.split("."))
    )


def test_clean_install_covers_supported_platforms():
    workflow = yaml.safe_load(
        Path(".github/workflows/tests.yml").read_text(encoding="utf-8")
    )
    job = workflow["jobs"]["clean-install"]
    assert set(job["strategy"]["matrix"]["os"]) == set(REQUIRED_TEST_RUNNERS.values())
    assert job["strategy"]["fail-fast"] is False
    assert job["env"]["OPUS_REF"] == "${{ github.sha }}"


def test_ci_runs_complete_unit_and_current_panel_suites():
    workflow = Path(".github/workflows/tests.yml").read_text(encoding="utf-8")
    assert "uv run pytest -q -n 2 tests" in workflow
    assert "e2e/test_opus_panel.py" in workflow
    assert "ruff check" in workflow
    assert "ty check" in workflow
