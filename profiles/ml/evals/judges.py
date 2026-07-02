"""Pluggable eval-judge seam — provider-neutral, offline-by-default.

A *judge* scores one eval case:

    def score(self, prompt, candidate, expected, rubric) -> float   # in [0, 1]

The interface is provider-neutral. Three reference judges live behind it:

  - ``ExactMatchJudge``  — exact-match (1.0/0.0), ignores the rubric. Offline. DEFAULT.
  - ``FakeRubricJudge``  — offline, rubric-shaped: a deterministic score from rubric
                           keyword coverage of the candidate, so CI can exercise the
                           rubric/judge dispatch path with no network and no API key.
  - ``ClaudeJudge``      — the pinned, INDEPENDENT reference adapter. Lazily imports the
                           ``anthropic`` SDK inside ``score`` (constructing the other
                           judges needs no SDK), pins a model in ``PINNED_JUDGE_MODEL``,
                           calls the messages API with ``temperature=0``, refuses to
                           self-grade, and parses a 0..1 score from the reply.

Claude is the default reference *adapter*, not the interface — an adopter can drop in an
OpenAI/Gemini/local/human judge behind the same ``score(...)`` signature.
"""
from __future__ import annotations

import re

# Pinned judge model. A judge MUST be pinned so scores stay comparable over time —
# an unpinned model drifts the quality bar underneath you. Pin a dated snapshot from
# the Anthropic SDK/docs for full reproducibility; this default names the current
# Claude model family.
PINNED_JUDGE_MODEL = "claude-opus-4-8"

# Cap the judge reply so a runaway generation can't dominate cost/latency.
_MAX_JUDGE_TOKENS = 16


class ExactMatchJudge:
    """Exact-match rubric (1.0/0.0). Ignores the rubric. Offline. The DEFAULT judge."""

    def score(self, prompt, candidate, expected, rubric) -> float:
        return 1.0 if candidate.strip().lower() == expected.strip().lower() else 0.0


class FakeRubricJudge:
    """Offline, rubric-shaped judge.

    Returns a deterministic score = (rubric keywords covered by the candidate) /
    (rubric keywords total). Its purpose is to exercise the judge-dispatch + rubric
    plumbing code path green-on-clone, with no network and no API key — so the seam
    itself is non-vacuously tested, not just the exact-match path.
    """

    def score(self, prompt, candidate, expected, rubric) -> float:
        keywords = [w for w in re.split(r"\W+", (rubric or "").lower()) if w]
        if not keywords:
            # No rubric to grade against: fall back to exact-match so an empty
            # rubric is safe and deterministic rather than undefined.
            return 1.0 if candidate.strip().lower() == expected.strip().lower() else 0.0
        cand = candidate.lower()
        covered = sum(1 for k in set(keywords) if k in cand)
        return covered / len(set(keywords))


class ClaudeJudge:
    """Pinned, independent Claude reference adapter (opt-in; never the CI default).

    Lazily imports ``anthropic`` inside ``score`` so constructing this judge — or the
    offline judges — never requires the SDK. Enforces judge independence: the judge
    model must differ from the system-under-test model (no self-grading).
    """

    def __init__(self, judge_model: str = PINNED_JUDGE_MODEL, sut_model: str | None = None):
        # judge independence: refuse to grade a system with the same model that
        # produced its output — a judge grading itself is not an independent oracle.
        if sut_model is not None and judge_model == sut_model:
            raise ValueError(
                "judge independence violated: judge_model must differ from sut_model "
                f"(both are {judge_model!r}); grade with a different, pinned model."
            )
        self.judge_model = judge_model
        self.sut_model = sut_model

    def score(self, prompt, candidate, expected, rubric) -> float:
        # Lazy import: the SDK is only needed when a live judge is actually invoked,
        # keeping the harness green-on-clone with no `anthropic` installed.
        import anthropic

        client = anthropic.Anthropic()
        instruction = (
            "You are an impartial eval judge. Given the task prompt, a candidate answer, "
            "the expected/reference answer, and a rubric, reply with a single number in "
            "[0,1] scoring how well the candidate satisfies the rubric. Reply with the "
            "number only.\n\n"
            f"PROMPT:\n{prompt}\n\nCANDIDATE:\n{candidate}\n\nEXPECTED:\n{expected}\n\n"
            f"RUBRIC:\n{rubric}\n"
        )
        message = client.messages.create(
            model=self.judge_model,
            max_tokens=_MAX_JUDGE_TOKENS,
            temperature=0,
            messages=[{"role": "user", "content": instruction}],
        )
        text = "".join(
            block.text for block in message.content if getattr(block, "type", None) == "text"
        )
        return self._parse_score(text)

    @staticmethod
    def _parse_score(text: str) -> float:
        match = re.search(r"[01](?:\.\d+)?|0?\.\d+", text.strip())
        if not match:
            raise ValueError(f"could not parse a 0..1 score from judge reply: {text!r}")
        value = float(match.group(0))
        # Clamp to the contract range in case the judge over/undershoots.
        return max(0.0, min(1.0, value))


_JUDGES = {
    "exact": ExactMatchJudge,
    "fake": FakeRubricJudge,
    "claude": ClaudeJudge,
}


def load_judge(name: str):
    """Factory: map a judge name to a constructed judge. Default selector is ``exact``."""
    try:
        cls = _JUDGES[name]
    except KeyError:
        raise ValueError(
            f"unknown judge {name!r}; choose one of {sorted(_JUDGES)}"
        ) from None
    return cls()
