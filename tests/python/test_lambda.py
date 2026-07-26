# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
"""Tests for scripts/check_lambda_permission_source_arn.py.

The script is stdlib-only Python; tests run with pytest.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Add scripts/ to sys.path so we can import the module under test.
SCRIPTS_DIR = Path(__file__).resolve().parent.parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

# pylint: disable=wrong-import-position
import check_lambda_permission_source_arn as clpsa  # noqa: E402


FIXTURES = Path(__file__).resolve().parent.parent / "fixtures"


@pytest.fixture
def valid_template() -> Path:
    return FIXTURES / "sam-template-valid" / "template.yaml"


@pytest.fixture
def missing_sourcearn_template() -> Path:
    return FIXTURES / "sam-template-missing-sourcearn" / "template.yaml"


@pytest.fixture
def comments_and_edges_template() -> Path:
    return FIXTURES / "sam-template-comments-and-edges" / "template.yaml"


@pytest.fixture
def mixed_resources_template() -> Path:
    return FIXTURES / "sam-template-mixed-resources" / "template.yaml"


@pytest.fixture
def no_permissions_template() -> Path:
    return FIXTURES / "sam-template-no-permissions" / "template.yaml"


# ---------------------------------------------------------------------------
# _scan_template
# ---------------------------------------------------------------------------


class TestScanTemplate:
    def test_all_permissions_have_sourcearn_or_sourceaccount(
        self, valid_template: Path
    ):
        offenders = clpsa._scan_template(valid_template)
        assert offenders == [], (
            f"valid template produced offenders: {offenders}"
        )

    def test_missing_sourcearn_caught_with_line_number(
        self, missing_sourcearn_template: Path
    ):
        offenders = clpsa._scan_template(missing_sourcearn_template)
        assert len(offenders) == 1
        logical_id, line_no = offenders[0]
        assert logical_id == "AuthorizerFunctionPermission"
        assert line_no == 4  # 1-indexed line of the resource header

    def test_commented_sourcearn_does_not_count_as_fix(
        self, comments_and_edges_template: Path
    ):
        """A `# SourceArn: ...` comment must NOT satisfy the check."""
        offenders = clpsa._scan_template(comments_and_edges_template)
        # Only AuthorizerFunctionPermission is missing; the others have
        # real (non-commented) SourceArn/SourceAccount.
        assert len(offenders) == 1
        logical_id, _ = offenders[0]
        assert logical_id == "AuthorizerFunctionPermission"

    def test_nested_sourcearn_value_is_detected(
        self, comments_and_edges_template: Path
    ):
        """SourceArn: with a nested Fn::Sub value should still satisfy."""
        offenders = clpsa._scan_template(comments_and_edges_template)
        logical_ids = [logical_id for logical_id, _ in offenders]
        assert "NestedPropertyPermission" not in logical_ids

    def test_non_permission_resources_ignored(
        self, mixed_resources_template: Path
    ):
        """S3 buckets and other resources must not appear in offenders."""
        offenders = clpsa._scan_template(mixed_resources_template)
        assert offenders == []

    def test_template_without_any_permission_has_no_offenders(
        self, no_permissions_template: Path
    ):
        offenders = clpsa._scan_template(no_permissions_template)
        assert offenders == []

    def test_lambda_alias_resource_not_matched(
        self, comments_and_edges_template: Path
    ):
        """A resource with Type=AWS::Lambda::Alias must NOT be picked up
        as a Permission (regression guard for the PERMISSION_HEADER regex)."""
        offenders = clpsa._scan_template(comments_and_edges_template)
        logical_ids = [logical_id for logical_id, _ in offenders]
        assert "NoTypePermission" not in logical_ids

    def test_scan_returns_logical_id_and_line_number(
        self, missing_sourcearn_template: Path
    ):
        offenders = clpsa._scan_template(missing_sourcearn_template)
        assert all(
            isinstance(item, tuple) and len(item) == 2 for item in offenders
        )
        for logical_id, line_no in offenders:
            assert isinstance(logical_id, str)
            assert isinstance(line_no, int)
            assert line_no > 0


# ---------------------------------------------------------------------------
# _resolve_scan_paths
# ---------------------------------------------------------------------------


class TestResolveScanPaths:
    def test_explicit_file_path_returned_as_is(self, valid_template: Path):
        paths = clpsa._resolve_scan_paths([str(valid_template)])
        assert valid_template in paths
        assert len(paths) == 1

    def test_glob_finds_all_template_yaml(self):
        paths = clpsa._resolve_scan_paths([str(FIXTURES)])
        # At least one fixture has template.yaml. We expect the deduped
        # set; ordering should be deterministic (sorted).
        assert len(paths) >= 1
        assert all(p.name == "template.yaml" for p in paths)

    def test_deduplicates_overlapping_inputs(self, valid_template: Path):
        # Same input twice should produce one entry.
        paths = clpsa._resolve_scan_paths(
            [str(valid_template), str(valid_template)]
        )
        assert len(paths) == 1

    def test_nonexistent_path_silently_skipped(self, tmp_path: Path):
        ghost = tmp_path / "does-not-exist.yaml"
        paths = clpsa._resolve_scan_paths([str(ghost)])
        # is_file() is False, and glob over a non-existent dir is empty.
        assert paths == []


# ---------------------------------------------------------------------------
# CLI entry point (subprocess)
# ---------------------------------------------------------------------------


class TestCli:
    def test_clean_template_exits_zero(
        self, valid_template: Path
    ):
        import subprocess

        result = subprocess.run(
            [sys.executable, str(SCRIPTS_DIR / "check_lambda_permission_source_arn.py"), str(valid_template.parent)],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0, (
            f"stdout={result.stdout!r} stderr={result.stderr!r}"
        )
        assert "OK" in result.stdout

    def test_offending_template_exits_one(
        self, missing_sourcearn_template: Path
    ):
        import subprocess

        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS_DIR / "check_lambda_permission_source_arn.py"),
                str(missing_sourcearn_template),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 1
        assert "AuthorizerFunctionPermission" in result.stderr
        assert "SourceArn" in result.stderr  # guidance message

    def test_no_files_found_exits_zero(self, tmp_path: Path):
        import subprocess

        empty = tmp_path / "empty-folder"
        empty.mkdir()
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS_DIR / "check_lambda_permission_source_arn.py"),
                str(empty),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0
        assert "No template.yaml files found" in result.stderr
