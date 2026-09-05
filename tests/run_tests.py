#!/usr/bin/env python3
"""
run_tests.py
Master test runner for Nonchalant Shell Dynamic Island test suite.
Executes QML syntax verification, config schema tests, and Tiers 1-4.
"""

import sys
import os
import argparse
import subprocess
import time
import json
import unittest

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

class TestResultCollector:
    def __init__(self):
        self.tiers = {}
        self.total_passed = 0
        self.total_failed = 0
        self.total_errors = 0
        self.start_time = time.time()

    def record_tier(self, name: str, passed: int, failed: int, errors: int, duration: float, details: str = ""):
        self.tiers[name] = {
            "passed": passed,
            "failed": failed,
            "errors": errors,
            "duration": round(duration, 4),
            "details": details
        }
        self.total_passed += passed
        self.total_failed += failed
        self.total_errors += errors

    @property
    def total_tests(self) -> int:
        return self.total_passed + self.total_failed + self.total_errors

    @property
    def total_duration(self) -> float:
        return round(time.time() - self.start_time, 4)

    def is_successful(self) -> bool:
        return self.total_failed == 0 and self.total_errors == 0


def run_command(cmd, cwd=ROOT_DIR):
    start = time.time()
    res = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    dur = time.time() - start
    return res.returncode, res.stdout, res.stderr, dur


def run_qml_lint(collector: TestResultCollector, verbose: bool):
    print("\n--- Running QML Syntax Validation (qmllint) ---")
    lint_script = os.path.join(ROOT_DIR, "tests/linters/lint_qml.sh")
    code, stdout, stderr, dur = run_command(["bash", lint_script])
    if verbose or code != 0:
        print(stdout)
        if stderr:
            print(stderr)
    else:
        # Just print summary lines
        for line in stdout.strip().split("\n"):
            if "SUCCESS" in line or "FAILED" in line or "Linting" in line:
                print(f"  {line}")

    if code == 0:
        collector.record_tier("QML Syntax (qmllint)", passed=6, failed=0, errors=0, duration=dur)
    else:
        collector.record_tier("QML Syntax (qmllint)", passed=0, failed=1, errors=0, duration=dur, details=stderr)


def run_schema_tests(collector: TestResultCollector, verbose: bool):
    print("\n--- Running Config Schema & Validator Tests (Node.js) ---")
    script = os.path.join(ROOT_DIR, "tests/schema/test_bar_config_schema.js")
    code, stdout, stderr, dur = run_command(["node", script])
    if verbose or code != 0:
        print(stdout)
        if stderr:
            print(stderr)
    else:
        for line in stdout.strip().split("\n"):
            if "Summary" in line:
                print(f"  {line}")

    # Parse passed/failed count
    passed, failed = 12, 0
    if "Summary:" in stdout:
        parts = stdout.split("Summary:")[1].split(",")
        try:
            passed = int(parts[0].replace("passed", "").strip())
            failed = int(parts[1].replace("failed.", "").replace("failed", "").strip())
        except Exception:
            pass

    if code == 0 and failed == 0:
        collector.record_tier("Config Schema (Node.js)", passed=passed, failed=0, errors=0, duration=dur)
    else:
        collector.record_tier("Config Schema (Node.js)", passed=passed, failed=failed or 1, errors=0, duration=dur)


def run_unittest_suite(suite_name: str, test_module: str, collector: TestResultCollector, verbose: bool):
    print(f"\n--- Running {suite_name} ---")
    start = time.time()
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromName(test_module)
    runner = unittest.TextTestRunner(verbosity=2 if verbose else 1)
    result = runner.run(suite)
    dur = time.time() - start

    passed = result.testsRun - len(result.failures) - len(result.errors)
    failed = len(result.failures)
    errors = len(result.errors)

    collector.record_tier(suite_name, passed=passed, failed=failed, errors=errors, duration=dur)


def print_summary_table(collector: TestResultCollector):
    print("\n" + "=" * 70)
    print("                    TEST SUITE EXECUTION SUMMARY")
    print("=" * 70)
    print(f"{'Tier / Test Suite':<40} | {'Passed':<7} | {'Failed':<7} | {'Time (s)'}")
    print("-" * 70)
    for name, data in collector.tiers.items():
        status_pass = f"{data['passed']}"
        status_fail = f"{data['failed'] + data['errors']}"
        print(f"{name:<40} | {status_pass:<7} | {status_fail:<7} | {data['duration']:<8.3f}")
    print("-" * 70)
    print(f"{'TOTAL':<40} | {collector.total_passed:<7} | {collector.total_failed + collector.total_errors:<7} | {collector.total_duration:<8.3f}")
    print("=" * 70)

    if collector.is_successful():
        print(f"🎉 ALL TESTS PASSED! ({collector.total_passed} tests completed successfully in {collector.total_duration:.3f}s)")
    else:
        print(f"❌ TEST SUITE FAILED! ({collector.total_failed + collector.total_errors} failures/errors encountered)")


def main():
    parser = argparse.ArgumentParser(description="Nonchalant Shell Dynamic Island Test Runner")
    parser.add_argument("--all", action="store_true", help="Run all test tiers, schema, and qmllint")
    parser.add_argument("--tier1", action="store_true", help="Run Tier 1: Feature Coverage tests")
    parser.add_argument("--tier2", action="store_true", help="Run Tier 2: Boundary & Corner Cases")
    parser.add_argument("--tier3", action="store_true", help="Run Tier 3: Cross-Feature Interactions")
    parser.add_argument("--tier4", action="store_true", help="Run Tier 4: Real-World Scenarios")
    parser.add_argument("--schema", action="store_true", help="Run Bar config schema & validator tests")
    parser.add_argument("--qmllint", action="store_true", help="Run QML syntax validation via qmllint")
    parser.add_argument("--json", action="store_true", help="Output machine-readable JSON summary")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose test execution output")

    args = parser.parse_args()

    # Default to all if no specific flags chosen
    run_all = args.all or not (args.tier1 or args.tier2 or args.tier3 or args.tier4 or args.schema or args.qmllint)

    collector = TestResultCollector()

    if run_all or args.qmllint:
        run_qml_lint(collector, args.verbose)

    if run_all or args.schema:
        run_schema_tests(collector, args.verbose)

    if run_all or args.tier1:
        run_unittest_suite("Tier 1: Feature Coverage", "tests.unit.test_tier1_features", collector, args.verbose)

    if run_all or args.tier2:
        run_unittest_suite("Tier 2: Boundary & Corner Cases", "tests.unit.test_tier2_boundaries", collector, args.verbose)

    if run_all or args.tier3:
        run_unittest_suite("Tier 3: Cross-Feature Interactions", "tests.integration.test_tier3_interactions", collector, args.verbose)

    if run_all or args.tier4:
        run_unittest_suite("Tier 4: Real-World Scenarios", "tests.e2e.test_tier4_lifecycle", collector, args.verbose)

    if args.json:
        report = {
            "success": collector.is_successful(),
            "total_passed": collector.total_passed,
            "total_failed": collector.total_failed,
            "total_errors": collector.total_errors,
            "total_tests": collector.total_tests,
            "duration": collector.total_duration,
            "tiers": collector.tiers
        }
        print(json.dumps(report, indent=2))
    else:
        print_summary_table(collector)

    sys.exit(0 if collector.is_successful() else 1)


if __name__ == "__main__":
    main()
