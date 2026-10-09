"""Workflow events, checkout identity and publishing privileges are contracts."""

import shlex
from pathlib import Path

import pytest
import yaml

from tests.scripts.test_version_policy import commit, git, write

ROOT = Path(__file__).resolve().parents[2]


def load(name):
    return yaml.safe_load(
        (ROOT / ".github/workflows" / name).read_text(encoding="utf-8")
    )


def test_fork_never_publishes_to_upstream_pypi():
    workflow = load("tests.yml")
    assert workflow["permissions"] == {"contents": "read"}
    assert not (ROOT / ".github/workflows/post-merge.yml").exists()
    assert "id-token: write" not in (ROOT / ".github/workflows/tests.yml").read_text()


@pytest.mark.parametrize("conflicting_tag", [False, True])
def test_ci_tag_fetch_uses_only_canonical_tags(tmp_path, conflicting_tag):
    upstream = tmp_path / "upstream.git"
    upstream.mkdir()
    git(upstream, "init", "-b", "main")
    write(upstream, "file", "release")
    released = commit(upstream)
    git(upstream, "tag", "-a", "v1.2.3", "-m", "release")
    checkout = tmp_path / "fork"
    git(tmp_path, "clone", str(upstream), str(checkout))
    write(checkout, "file", "pull request")
    head = commit(checkout)
    git(checkout, "tag", "v99.0.0")
    if conflicting_tag:
        git(checkout, "tag", "-f", "v1.2.3")
    write(upstream, "file", "new release")
    latest = commit(upstream)
    git(upstream, "tag", "v1.2.4")

    setup = yaml.safe_load(
        (ROOT / ".github/actions/ci-environment/action.yml").read_text()
    )
    command = shlex.split(setup["runs"]["steps"][0]["run"])
    command = [
        arg.replace("$CI_SERVER/$CI_REPOSITORY.git", upstream.as_posix())
        for arg in command
    ]
    assert command[0] == "git"
    for _ in range(2):
        git(checkout, *command[1:])
        assert git(checkout, "tag", "--list").splitlines() == ["v1.2.3", "v1.2.4"]
        assert git(checkout, "rev-parse", "v1.2.3^{}") == released
        assert git(checkout, "rev-parse", "v1.2.4") == latest
        assert git(checkout, "rev-parse", "HEAD") == head
        assert git(checkout, "status", "--porcelain") == ""
