"""Reference eval harness — deterministic, offline (no network, no API key).

This is the SHIPPED REFERENCE so the `gate-eval` CI step is green the moment you clone
the profile, with no secrets configured. It demonstrates the harness *mechanics* the
§7 eval gate depends on: load a golden set, run the system under test, score each case
against a rubric, aggregate, and FAIL the build below `--threshold`.

It is intentionally a placeholder, not a real model evaluation. To make it real:
  1. Replace `generate()` with your model/prompt call.
  2. Replace `golden.jsonl` with your curated dataset (grow it from production misses).
  3. Select a graded/LLM-as-judge scorer via `--judge` (see judges.py + rubric.md).
See rubric.md for the upgrade recipe. Run: `python -m evals.run --threshold 0.8`.

Scoring is a pluggable seam (`judges.py`): `--judge {exact,fake,claude}` selects the
judge; the default is offline exact-match so `gate-eval` is green-on-clone with no key.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sys

try:  # allow both `python -m evals.run` and `python run.py`
    from judges import load_judge
except ImportError:  # pragma: no cover - packaged import path
    from .judges import load_judge

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_DATA = HERE / "golden.jsonl"

_POSITIVE = ("love", "great", "excellent", "perfect", "amazing")
_NEGATIVE = ("hate", "terrible", "broken", "awful", "worst")


def generate(prompt: str) -> str:
    """STUB system-under-test — REPLACE with your model/prompt call.

    Deterministic rule-based sentiment tagger so the reference suite passes offline.
    A real implementation would call your model (e.g. the Anthropic SDK) here.
    """
    text = prompt.lower()
    if any(w in text for w in _POSITIVE):
        return "positive"
    if any(w in text for w in _NEGATIVE):
        return "negative"
    return "neutral"


def load_cases(path: str) -> list:
    cases = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                cases.append(json.loads(line))
    return cases


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Reference eval gate (deterministic, offline).")
    ap.add_argument("--threshold", type=float, default=0.8, help="minimum mean score to pass")
    ap.add_argument("--data", default=str(DEFAULT_DATA), help="path to a JSONL golden set")
    # offline by default: exact-match needs no network/key; claude is opt-in.
    ap.add_argument(
        "--judge",
        choices=["exact", "fake", "claude"],
        default="exact",
        help="scoring judge (default offline exact-match; claude is opt-in, needs a key)",
    )
    args = ap.parse_args(argv)

    cases = load_cases(args.data)
    if not cases:
        print(f"eval: no cases found in {args.data}", file=sys.stderr)
        return 1

    judge = load_judge(args.judge)

    total = 0.0
    for c in cases:
        prompt = c["input"]
        candidate = generate(prompt)
        expected = c["expected"]
        # Thread a per-case rubric through the seam (default to empty if absent).
        rubric = c.get("rubric", "")
        s = judge.score(prompt, candidate, expected, rubric)
        total += s
        mark = "ok  " if s >= 1.0 else "MISS"
        print(f"  [{mark}] {c.get('id', '?')}: got={candidate!r} expected={expected!r} score={s:.2f}")

    mean = total / len(cases)
    print(f"eval: mean score {mean:.3f} over {len(cases)} cases (threshold {args.threshold})")
    if mean < args.threshold:
        print(f"eval: FAIL — below threshold {args.threshold}", file=sys.stderr)
        return 1
    print("eval: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
