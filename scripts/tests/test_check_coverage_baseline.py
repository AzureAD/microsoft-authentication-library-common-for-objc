# Copyright (c) Microsoft Corporation.
# All rights reserved.
#
# This code is licensed under the MIT License.

"""Exercise warning-only baseline checks without Xcode or Azure Pipelines."""

import importlib.util
import io
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "check_coverage_baseline.py"
SPEC = importlib.util.spec_from_file_location("check_coverage_baseline", SCRIPT)
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


class CoverageBaselineTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.report = Path(self.temp.name) / "Cobertura.xml"

    def write_report(self, covered="71", valid="100", rate="0.71"):
        self.report.write_text(
            f'<coverage lines-covered="{covered}" lines-valid="{valid}" '
            f'line-rate="{rate}"><packages/></coverage>', encoding="utf-8"
        )

    def run_check(self, minimum="71", suite="IdentityCore iOS", revision="abc123",
                  report=None):
        output = io.StringIO()
        with redirect_stdout(output):
            code = checker.main([
                "--report", str(self.report if report is None else report),
                "--suite", suite, "--minimum", minimum, "--revision", revision,
            ])
        return code, output.getvalue()

    def assert_warning(self, output):
        self.assertIn("##vso[task.logissue type=warning]", output)
        self.assertEqual(output.count("##vso[task.complete result=SucceededWithIssues;]"), 1)
        self.assertNotIn("result=Failed", output)

    def test_above_and_equal_pass_without_warning(self):
        for covered in ("72", "71"):
            with self.subTest(covered=covered):
                self.write_report(covered)
                code, output = self.run_check()
                self.assertEqual(code, 0)
                self.assertIn("at or above minimum", output)
                self.assertNotIn("##vso[", output)

    def test_below_warns_and_exits_zero_with_provenance(self):
        self.write_report("70")
        code, output = self.run_check()
        self.assertEqual(code, 0)
        self.assert_warning(output)
        for detail in ("IdentityCore iOS", "70/100", "70.000000%", "71%", "abc123"):
            self.assertIn(detail, output)

    def test_exact_comparison_ignores_rounded_rate_and_display(self):
        self.write_report("70999999999", "100000000000", "0.71")
        code, output = self.run_check()
        self.assertEqual(code, 0)
        self.assertIn("71.000000%", output)
        self.assert_warning(output)
        self.write_report("71", "100", "0")
        self.assertNotIn("##vso[", self.run_check()[1])

    def test_schemes_and_known_hosted_counts_are_independent(self):
        self.write_report("70")
        self.assert_warning(self.run_check()[1])
        self.assertNotIn("##vso[", self.run_check(minimum="63", suite="IdentityCore Mac")[1])
        for suite, covered, valid, minimum in (
            ("IdentityCore iOS", "25322", "34315", "71"),
            ("IdentityCore Mac", "23186", "35657", "63"),
        ):
            with self.subTest(suite=suite):
                self.write_report(covered, valid)
                self.assertNotIn("##vso[", self.run_check(minimum, suite)[1])

    def test_missing_empty_malformed_and_wrong_root_are_unavailable(self):
        for content in (None, "", "<coverage", "<not-coverage/>"):
            with self.subTest(content=content):
                if content is not None:
                    self.report.write_text(content, encoding="utf-8")
                code, output = self.run_check()
                self.assertEqual(code, 0)
                self.assert_warning(output)
                for detail in ("unavailable/incomplete", "actual=unavailable",
                               "minimum=71%", "revision=abc123"):
                    self.assertIn(detail, output)
                self.assertNotIn("at or above minimum", output)
                self.assertNotIn("actual=0", output)

    def test_quoted_glob_requires_exactly_one_report(self):
        pattern = self.report.parent / "*.xml"
        self.assertIn("found 0", self.run_check(report=pattern)[1])
        self.write_report()
        self.assertNotIn("##vso[", self.run_check(report=pattern)[1])
        (self.report.parent / "duplicate.xml").write_text(self.report.read_text())
        code, output = self.run_check(report=pattern)
        self.assertEqual(code, 0)
        self.assert_warning(output)
        self.assertIn("found 2", output)
        self.assertIn("actual=unavailable", output)

    def test_invalid_missing_or_inconsistent_counts_are_unavailable(self):
        for covered, valid in (
            ("-1", "100"), ("101", "100"), ("0", "0"), ("0", "-1"),
            ("1.5", "100"), ("1", "1.5"), ("nan", "100"),
            ("1", "inf"), ("", "100"), ("1", ""), ("+1", "100"),
        ):
            with self.subTest(covered=covered, valid=valid):
                self.write_report(covered, valid)
                code, output = self.run_check()
                self.assertEqual(code, 0)
                self.assert_warning(output)
                self.assertIn("unavailable/incomplete", output)
        self.report.write_text('<coverage line-rate="1"/>')
        self.assertIn("unavailable/incomplete", self.run_check()[1])

    def test_zero_covered_is_real_zero_when_denominator_is_valid(self):
        self.write_report("0")
        self.assert_warning(self.run_check()[1])
        self.assertIn("actual=0.000000%", self.run_check()[1])

    def test_minimum_endpoints_and_decimal_boundary(self):
        for covered, minimum in (("0", "0"), ("100", "100"), ("71", "71.0")):
            self.write_report(covered)
            self.assertNotIn("##vso[", self.run_check(minimum=minimum)[1])
        self.write_report()
        self.assert_warning(self.run_check(minimum="71.000000000000001")[1])

    def test_bad_minimum_fails_even_without_report(self):
        for minimum in ("-1", "101", "NaN", "Infinity", "", "seventy"):
            with self.subTest(minimum=minimum), redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    self.run_check(minimum=minimum)
                self.assertEqual(error.exception.code, 2)

    def test_unexpected_io_and_programming_errors_propagate(self):
        self.write_report()
        for error in (PermissionError("unreadable"), OSError("I/O"), RuntimeError("bug")):
            with self.subTest(error=error), patch.object(checker.ET, "parse", side_effect=error):
                with patch.object(checker, "warn") as warning:
                    with self.assertRaises(type(error)):
                        self.run_check()
                    warning.assert_not_called()
        for error in (PermissionError("directory unreadable"), OSError("directory I/O"),
                      RuntimeError("bug")):
            with patch.object(checker.Path, "iterdir", side_effect=error):
                with self.assertRaises(type(error)):
                    self.run_check()

    def test_missing_directory_warns_but_wildcard_directory_is_invalid_configuration(self):
        code, output = self.run_check(report=self.report.parent / "missing" / "*.xml")
        self.assertEqual(code, 0)
        self.assert_warning(output)
        self.assertIn("report directory missing", output)
        with self.assertRaises(ValueError):
            self.run_check(report=self.report.parent / "*" / "*.xml")

    def test_disappearing_report_warns_unavailable(self):
        self.write_report()
        with patch.object(checker.ET, "parse", side_effect=FileNotFoundError("missing")):
            self.assert_warning(self.run_check()[1])

    def test_logging_command_data_is_escaped(self):
        self.write_report("70")
        _, output = self.run_check(revision="abc%\r\n##vso[task.complete result=Succeeded;]")
        self.assertNotIn("\n##vso[task.complete result=Succeeded;]", output)
        self.assertIn("abc%AZP25%0D%0A", output)
        self.assert_warning(output)

    def test_cli_quoted_glob_warns_zero_but_config_and_io_fail(self):
        args = [sys.executable, str(SCRIPT), "--report", str(self.report.parent / "*.xml"),
                "--suite", "IdentityCore iOS", "--revision", "abc123", "--minimum"]
        result = subprocess.run(args + ["71"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assert_warning(result.stdout)
        result = subprocess.run(args + ["bad"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("task.complete", result.stdout)
        self.report.mkdir()
        result = subprocess.run(args + ["71"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("task.complete", result.stdout)


if __name__ == "__main__":
    unittest.main()
