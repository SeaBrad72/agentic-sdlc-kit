"""Offline TDD proof for the pluggable eval-judge seam.

Runs with plain `python3 profiles/ml/evals/test_run.py` (unittest) OR under pytest.
Every test is OFFLINE: no network, no `anthropic` SDK required. The `ClaudeJudge`
adapter is exercised only for construction + the judge-independence guard — never
for a live API call.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import judges  # noqa: E402
import run  # noqa: E402

GOLDEN = os.path.join(HERE, "golden.jsonl")


class ExactJudgeGateTest(unittest.TestCase):
    def test_exact_judge_passes_golden_set(self):
        rc = run.main(["--judge", "exact", "--data", GOLDEN, "--threshold", "0.8"])
        self.assertEqual(rc, 0)

    def test_all_miss_dataset_fails_threshold(self):
        rows = [
            {"id": "m1", "input": "I love this product, it works great", "expected": "WRONG"},
            {"id": "m2", "input": "This is terrible and arrived broken", "expected": "WRONG"},
            {"id": "m3", "input": "It arrived on Tuesday in a cardboard box", "expected": "WRONG"},
        ]
        with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as fh:
            for r in rows:
                fh.write(json.dumps(r) + "\n")
            path = fh.name
        try:
            rc = run.main(["--judge", "exact", "--data", path, "--threshold", "0.8"])
            self.assertEqual(rc, 1)
        finally:
            os.unlink(path)


class FakeRubricJudgeTest(unittest.TestCase):
    def test_score_is_deterministic_rubric_coverage(self):
        j = judges.FakeRubricJudge()
        rubric = "positive negative neutral"
        # candidate covers 1 of 3 rubric keywords -> deterministic fraction.
        s1 = j.score("prompt", "positive", "positive", rubric)
        s2 = j.score("prompt", "positive", "positive", rubric)
        self.assertEqual(s1, s2)
        self.assertGreaterEqual(s1, 0.0)
        self.assertLessEqual(s1, 1.0)
        # more coverage -> higher (or equal) score.
        s_more = j.score("prompt", "positive negative neutral", "x", rubric)
        self.assertGreaterEqual(s_more, s1)
        self.assertEqual(s_more, 1.0)

    def test_empty_rubric_is_safe(self):
        j = judges.FakeRubricJudge()
        s = j.score("prompt", "anything", "expected", "")
        self.assertGreaterEqual(s, 0.0)
        self.assertLessEqual(s, 1.0)

    def test_dispatch_through_run_fake_offline(self):
        rc = run.main(["--judge", "fake", "--data", GOLDEN, "--threshold", "0.0"])
        self.assertEqual(rc, 0)


class LoadJudgeTest(unittest.TestCase):
    def test_load_judge_maps_names(self):
        self.assertIsInstance(judges.load_judge("exact"), judges.ExactMatchJudge)
        self.assertIsInstance(judges.load_judge("fake"), judges.FakeRubricJudge)

    def test_default_judge_is_exact(self):
        rc = run.main(["--data", GOLDEN, "--threshold", "0.8"])
        self.assertEqual(rc, 0)


class LazyImportTest(unittest.TestCase):
    def test_constructing_offline_judges_does_not_import_anthropic(self):
        # Run in a clean subprocess so module-import state is not polluted by
        # this process. Assert `anthropic` is absent from sys.modules after
        # constructing the offline judges and calling load_judge("exact").
        code = (
            "import sys; sys.path.insert(0, %r);"
            "import judges;"
            "judges.ExactMatchJudge(); judges.FakeRubricJudge();"
            "judges.load_judge('exact');"
            "assert 'anthropic' not in sys.modules, 'anthropic imported eagerly';"
            "print('OK')" % HERE
        )
        out = subprocess.run(
            [sys.executable, "-c", code],
            capture_output=True,
            text=True,
        )
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("OK", out.stdout)


class ClaudeJudgeIndependenceTest(unittest.TestCase):
    def test_same_model_raises(self):
        with self.assertRaises(ValueError):
            judges.ClaudeJudge(judge_model="X", sut_model="X")

    def test_distinct_models_construct(self):
        j = judges.ClaudeJudge(judge_model="judge-A", sut_model="sut-B")
        self.assertIsInstance(j, judges.ClaudeJudge)

    def test_default_judge_model_is_pinned_constant(self):
        j = judges.ClaudeJudge(sut_model="some-sut-model")
        self.assertEqual(j.judge_model, judges.PINNED_JUDGE_MODEL)


if __name__ == "__main__":
    unittest.main(verbosity=2)
