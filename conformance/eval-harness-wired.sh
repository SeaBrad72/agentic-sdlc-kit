#!/bin/sh
# Why this gate: sparkwright explain evals
# eval-harness-wired.sh -- kit-self structural lock for the reference eval-judge SEAM (E6-a).
#
# Asserts the reference eval harness (profiles/ml/evals/) embodies the eval-driven best
# practices the `evals` skill prescribes -- as CODE structure, not just prose:
#   (a) a provider-neutral pluggable judge SEAM: score(self, prompt, candidate, expected, rubric)
#       with >= 2 judges behind it, incl. a rubric-shaped one (FakeRubricJudge);
#   (b) a PINNED judge model (PINNED_JUDGE_MODEL) + deterministic temperature=0;
#   (c) judge INDEPENDENCE enforced (refuse judge_model == sut_model -- no self-grading);
#   (d) OFFLINE-BY-DEFAULT: run.py default judge is exact (needs no key), and the Claude
#       adapter lazily imports `anthropic` (never at module top) so it is never the CI default.
#
# SCOPE -- a green run proves the reference harness is WIRED to these practices; it does NOT
# run a live model or prove any model meets a quality bar (that is the adopter's live run; the
# §7 Eval gate). Honest ceiling: provided + structurally proven; live-eval-quality un-gateable.
# Kit-self check: N/A outside the kit repo (no docs/ROADMAP-KIT.md and no profiles/ml/evals).
#
# Usage:
#   sh conformance/eval-harness-wired.sh            (main-path: check the real reference files)
#   sh conformance/eval-harness-wired.sh --selftest (fixture-driven anchor + load-bearing negatives)
# Exit: 0 = OK or N/A -- 1 = FAIL (reference harness under-wired). POSIX sh; dash-clean.
set -eu

JUDGES_FILE="${EVAL_HARNESS_JUDGES:-profiles/ml/evals/judges.py}"
RUN_FILE="${EVAL_HARNESS_RUN:-profiles/ml/evals/run.py}"

# The provider-neutral seam signature (kit-distinctive; a generic scorer lacks the rubric arg).
SEAM_SIG='def score(self, prompt, candidate, expected, rubric)'

check_harness() {
  jf=$1; rf=$2; miss=0
  [ -f "$jf" ] || { echo "FAIL: missing judges file $jf"; return 1; }
  [ -f "$rf" ] || { echo "FAIL: missing run file $rf"; return 1; }

  # (a) the pluggable seam + >= 2 judges incl. the rubric-shaped one
  grep -qF -- "$SEAM_SIG" "$jf" || { echo "FAIL: $jf missing the provider-neutral seam signature '$SEAM_SIG' (no pluggable judge seam)"; miss=1; }
  n_judges=$(grep -cE '^class [A-Za-z_]+Judge' "$jf" || true)
  [ "$n_judges" -ge 2 ] || { echo "FAIL: $jf defines $n_judges judge class(es); the seam needs >= 2 (a generic single scorer is not a seam)"; miss=1; }
  grep -qE '^class FakeRubricJudge' "$jf" || { echo "FAIL: $jf has no FakeRubricJudge (the offline rubric-shaped judge that exercises the seam green-on-clone)"; miss=1; }

  # (b) pinned judge model + deterministic judge
  grep -qF -- "PINNED_JUDGE_MODEL" "$jf" || { echo "FAIL: $jf has no PINNED_JUDGE_MODEL (an unpinned judge drifts the quality bar)"; miss=1; }
  grep -qF -- "temperature=0" "$jf"      || { echo "FAIL: $jf judge is not pinned to temperature=0 (non-deterministic judge)"; miss=1; }

  # (c) judge independence enforced (no self-grading)
  grep -qF -- "judge_model == sut_model" "$jf" || { echo "FAIL: $jf does not enforce judge independence (no judge_model == sut_model refusal)"; miss=1; }

  # (d) offline-by-default + lazy Claude adapter (never the CI default)
  grep -qF -- 'default="exact"' "$rf" || { echo "FAIL: $rf default judge is not the offline exact-match (offline-by-default broken)"; miss=1; }
  grep -qF -- 'default="claude"' "$rf" && { echo "FAIL: $rf makes the live Claude judge the DEFAULT (breaks green-on-clone / no-live-keys)"; miss=1; }
  grep -qF -- "import anthropic" "$jf" || { echo "FAIL: $jf never imports the anthropic SDK (no reference adapter)"; miss=1; }
  if grep -Eq '^(import|from) anthropic' "$jf"; then
    echo "FAIL: $jf imports anthropic at MODULE TOP (not lazy) -- the harness would require the SDK/key even offline"; miss=1
  fi

  return $miss
}

# ---------------------------------------------------------------------------------------------
if [ "${1:-}" = "--selftest" ]; then
  d=$(mktemp -d "${TMPDIR:-/tmp}/eval-harness.XXXXXX"); trap 'rm -rf "$d"' EXIT INT TERM
  st=0

  # Build a fully-conformant fixture (minimal, carrying every marker).
  build_fixture() {
    t=$1; mkdir -p "$t"
    cat > "$t/judges.py" <<'PYJ'
PINNED_JUDGE_MODEL = "claude-opus-4-8"
class ExactMatchJudge:
    def score(self, prompt, candidate, expected, rubric):
        return 1.0
class FakeRubricJudge:
    def score(self, prompt, candidate, expected, rubric):
        return 1.0
class ClaudeJudge:
    def __init__(self, judge_model=PINNED_JUDGE_MODEL, sut_model=None):
        # judge independence
        if sut_model is not None and judge_model == sut_model:
            raise ValueError("judge independence violated")
    def score(self, prompt, candidate, expected, rubric):
        import anthropic  # lazy
        return anthropic.grade(temperature=0)
PYJ
    cat > "$t/run.py" <<'PYR'
# offline by default
def main():
    ap_add("--judge", default="exact")
    return load_judge("exact")
PYR
  }

  run_fixture() {  # echo the check's exit code against fixture dir $1
    rc=0
    EVAL_HARNESS_JUDGES="$1/judges.py" EVAL_HARNESS_RUN="$1/run.py" \
      sh "$0" >/dev/null 2>&1 || rc=$?
    echo "$rc"
  }
  expect() {  # <label> <expected-rc>
    got=$(run_fixture "$d/fx")
    if [ "$got" = "$2" ]; then echo "selftest PASS: $1"; else echo "selftest FAIL: $1 (expected $2, got $got)"; st=1; fi
  }
  fresh() { rm -rf "$d/fx"; build_fixture "$d/fx"; }

  # liveness anchor: fully conformant -> exit 0
  fresh; expect "conformant reference harness -> exit 0" 0

  # load-bearing negatives (each mutates ONE property of the conformant fixture)
  fresh; sed 's/default="exact"/default="claude"/' "$d/fx/run.py" > "$d/fx/run.py.t" && mv "$d/fx/run.py.t" "$d/fx/run.py"
  expect "live Claude judge as DEFAULT -> exit 1" 1

  fresh; grep -v 'PINNED_JUDGE_MODEL' "$d/fx/judges.py" > "$d/fx/judges.py.t" && mv "$d/fx/judges.py.t" "$d/fx/judges.py"
  expect "unpinned judge (no PINNED_JUDGE_MODEL) -> exit 1" 1

  fresh; grep -v 'class FakeRubricJudge' "$d/fx/judges.py" > "$d/fx/judges.py.t" && mv "$d/fx/judges.py.t" "$d/fx/judges.py"
  expect "no rubric-shaped judge (seam collapsed) -> exit 1" 1

  fresh; grep -v 'judge_model == sut_model' "$d/fx/judges.py" > "$d/fx/judges.py.t" && mv "$d/fx/judges.py.t" "$d/fx/judges.py"
  expect "judge independence not enforced -> exit 1" 1

  fresh; printf 'import anthropic\n' | cat - "$d/fx/judges.py" > "$d/fx/judges.py.t" && mv "$d/fx/judges.py.t" "$d/fx/judges.py"
  expect "anthropic imported at MODULE TOP (not lazy) -> exit 1" 1

  if [ "$st" -ne 0 ]; then echo "eval-harness-wired --selftest: FAIL" >&2; exit 1; fi
  echo "eval-harness-wired --selftest: OK (anchor + 5 load-bearing negatives: default-claude/unpinned/no-seam/no-independence/eager-import)"
  exit 0
fi

case "${1:-}" in "") : ;; *) echo "usage: eval-harness-wired.sh [--selftest]" >&2; exit 2 ;; esac

# Kit-self scope: N/A outside the kit repo.
if [ ! -f "docs/ROADMAP-KIT.md" ] && [ ! -f "$JUDGES_FILE" ]; then
  echo "eval-harness: N/A -- kit-self check (the reference eval harness is the kit's own; not applicable outside the kit repo)"
  exit 0
fi

if check_harness "$JUDGES_FILE" "$RUN_FILE"; then
  echo "eval-harness: OK -- reference eval-judge seam wired (pluggable seam + >=2 judges + pinned+temperature=0 + judge-independence + offline-by-default lazy Claude adapter). NOTE: does NOT run a live model or prove a quality bar -- that is the adopter's §7 Eval gate."
  exit 0
fi
echo "FAIL: eval-harness under-wired (see reasons above)"
exit 1
