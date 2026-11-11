# Copyright (c) Microsoft Corporation.
# All rights reserved.
#
# This code is licensed under the MIT License.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Exercise command generation and the real build.py control flow without Xcode.
import ast
import contextlib
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch


ROOT = Path(__file__).resolve().parents[2]
TREE = ast.parse((ROOT / "build.py").read_text())
definitions = []
for statement in TREE.body:
    if isinstance(statement, ast.Assign) and any(
        isinstance(target, ast.Name) and target.id == "clean"
        for target in statement.targets
    ):
        break
    definitions.append(statement)
namespace = {}
with patch.dict(sys.modules, {"device_guids": Mock()}):
    exec(compile(ast.Module(body=definitions, type_ignores=[]), "build.py", "exec"), namespace)


class BuildCoverageTests(unittest.TestCase):
    def target(self, scheme="IdentityCore Mac", coverage=True, platform="Mac",
               operations=None):
        return namespace["BuildTarget"]({
            "name": scheme, "scheme": scheme, "platform": platform,
            "operations": operations if operations is not None else ["build", "test"],
        }, enable_coverage=coverage)

    def test_existing_targets_operations_and_destinations_are_preserved(self):
        specs = namespace["target_specifiers"]
        self.assertEqual(["ios_library", "mac_library", "vision_library"],
                         [spec["target"] for spec in specs])
        self.assertEqual([["build", "test"], ["build", "test"], ["build"]],
                         [spec["operations"] for spec in specs])
        command = self.target("IdentityCore iOS", platform="iOS").xcodebuild_command("test", False)
        self.assertIn("platform=iOS Simulator,name=iPhone 17,OS=26.1", command)
        self.assertIn('-sdk iphonesimulator CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO', command)
        self.assertIn("-parallel-testing-enabled NO", command)

    def test_build_and_test_share_scheme_local_data_but_not_result_bundle(self):
        first = self.target()
        second = self.target("IdentityCore iOS", platform="iOS")
        for target in [first, second]:
            build = target.xcodebuild_command("build", False)
            test = target.xcodebuild_command("test", False)
            self.assertIn("build-for-testing", build)
            self.assertIn("test-without-building", test)
            for command in [build, test]:
                self.assertIn("-enableCodeCoverage YES", command)
                self.assertIn(target.coverage_derived_data, command)
            self.assertNotIn("-resultBundlePath", build)
            self.assertIn(f"{target.coverage_name}.xcresult", test)
        self.assertNotEqual(first.coverage_derived_data, second.coverage_derived_data)
        self.assertEqual("IdentityCore_iOS", second.coverage_name)

    def test_noncoverage_and_build_only_commands_are_unchanged(self):
        for target in [self.target(coverage=False),
                       self.target(platform="visionOS", operations=["build"])]:
            command = target.xcodebuild_command("build", False)
            for flag in ["-enableCodeCoverage", "-derivedDataPath", "-resultBundlePath"]:
                self.assertNotIn(flag, command)

    def test_metadata_uses_same_derived_data_without_test_only_flags(self):
        target = self.target()
        command = target.xcodebuild_command(None, False)
        self.assertIn(target.coverage_derived_data, command)
        self.assertNotIn("-enableCodeCoverage", command)
        self.assertNotIn("-resultBundlePath", command)

    def test_export_is_immediate_and_scheme_independent(self):
        first = self.target()
        second = self.target("IdentityCore iOS", platform="iOS")
        commands = []
        with patch.object(subprocess, "call",
                          side_effect=lambda command, **kwargs: commands.append(command) or 0):
            first.do_operation("build")
            first.do_operation("test")
            second.do_operation("build")
        self.assertEqual(4, len(commands))
        self.assertEqual(["ruby", "scripts/coverage.rb", "export", first.scheme,
                          first.coverage_derived_data,
                          "./build/coverage/IdentityCore_Mac.xcresult"], commands[2])
        self.assertIn("IdentityCore iOS", commands[3])

    def test_failed_tests_still_export_and_keep_test_failure(self):
        target = self.target()
        with patch.object(subprocess, "call", side_effect=[65, 1]) as call:
            self.assertEqual(65, target.do_operation("test"))
        self.assertEqual(2, call.call_count)
        self.assertTrue(target.failed)

    def test_collection_failure_does_not_skip_other_scheme(self):
        first, second = self.target(), self.target("IdentityCore iOS", platform="iOS")
        with patch.object(subprocess, "call", side_effect=[0, 1, 0, 0]):
            self.assertEqual(1, first.do_operation("test"))
            self.assertEqual(0, second.do_operation("test"))
        self.assertTrue(first.failed)
        self.assertFalse(second.failed)

    def test_noncoverage_tests_do_not_export(self):
        with patch.object(subprocess, "call", return_value=0) as call:
            self.assertEqual(0, self.target(coverage=False).do_operation("test"))
        self.assertEqual(1, call.call_count)

    def test_main_records_failure_and_retains_other_schemes_without_global_cleanup(self):
        commands = []

        def execute(command, **kwargs):
            commands.append(command)
            return int(isinstance(command, list) and command[:4] ==
                       ["ruby", "scripts/coverage.rb", "export", "IdentityCore iOS"])

        original_directory = os.getcwd()
        with tempfile.TemporaryDirectory() as directory:
            try:
                os.chdir(directory)
                Path("build/coverage/reports").mkdir(parents=True)
                Path("build/coverage/reports/stale.xml").write_text("stale")
                script_namespace = {}
                device_guids = Mock()
                device_guids.get_ios.return_value = "fixture-device"
                with patch.dict(sys.modules, {"device_guids": device_guids}), \
                     patch.object(sys, "argv", ["build.py", "--coverage", "--targets",
                                               "ios_library", "mac_library"]), \
                     patch.object(subprocess, "call", side_effect=execute), \
                     patch.object(subprocess, "Popen"), \
                     contextlib.redirect_stdout(io.StringIO()):
                    with self.assertRaises(SystemExit) as result:
                        exec(compile(TREE, "build.py", "exec"), script_namespace)
                script_namespace["status_file"].close()
                self.assertEqual(1, result.exception.code)
                self.assertEqual("1", Path("status.txt").read_text())
                exports = [command[3] for command in commands if isinstance(command, list)]
                self.assertEqual(["IdentityCore iOS", "IdentityCore Mac"], exports)
                self.assertTrue(Path("coverage/reports").is_dir())
                self.assertFalse(Path("coverage/reports/stale.xml").exists())
                self.assertFalse(any(isinstance(command, str) and "rm -rf" in command
                                     for command in commands))
            finally:
                os.chdir(original_directory)


if __name__ == "__main__":
    unittest.main()
