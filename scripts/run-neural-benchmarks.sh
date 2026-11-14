#!/usr/bin/env bash
# Build a Pharo 14 image with this repository (and HeuristicCompletion-Benchmarks), then
#   1. split the packages of the image into training / validation / test packages (by project),
#   2. train and validate one neural re-ranker per kind of completion (messages, variables) and per
#      heuristic configuration (baseline, semantics, dependency),
#   3. test the six configurations on the test packages (Baseline, Baseline + Re-ranking, Semantics,
#      Semantics + Re-ranking, Dependency, Dependency + Re-ranking): accuracy, time and memory,
#   4. write the reports (summary.md / .csv / .tex, ...).
#
# Usage:
#   scripts/run-neural-benchmarks.sh            # the full experiment (about one hour, see README)
#   scripts/run-neural-benchmarks.sh --quick    # a small experiment (a few minutes), to try
#   scripts/run-neural-benchmarks.sh --tests    # only run the SUnit tests
#
# Environment variables (see the README for the NR_* ones, given to CooNeuralExperiment>>#fromEnvironment):
#   WORK_DIR         image, VM and results                       (default: ./neural-bench)
#   NR_OUTPUT        results directory                           (default: $WORK_DIR/results)
#   REPO             Metacello repository of this project        (default: this checkout, tonel://.../src)
#   BENCHMARKS_REPO  repository of HeuristicCompletion-Benchmarks (default: ../HeuristicCompletion-Benchmarks
#                    when it is checked out next to this one, else github://omarabedelkader/...:main/src)
#   PHARO_DIR        a directory with a Pharo 14 image and VM to copy instead of downloading one
#   REINSTALL        1 rebuilds the base image                    (default: 0)
#   RUN_TIMEOUT      seconds allowed for the experiment           (default: 21600)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="$(mkdir -p "${WORK_DIR:-$REPO_ROOT/neural-bench}" && cd "${WORK_DIR:-$REPO_ROOT/neural-bench}" && pwd)"
REPO="${REPO:-tonel://$REPO_ROOT/src}"
if [ -z "${BENCHMARKS_REPO:-}" ]; then
  if [ -d "$REPO_ROOT/../HeuristicCompletion-Benchmarks/src" ]; then
    BENCHMARKS_REPO="tonel://$(cd "$REPO_ROOT/../HeuristicCompletion-Benchmarks/src" && pwd)"
  else
    BENCHMARKS_REPO="github://omarabedelkader/HeuristicCompletion-Benchmarks:main/src"
  fi
fi
REINSTALL="${REINSTALL:-0}"
RUN_TIMEOUT="${RUN_TIMEOUT:-21600}"
export NR_OUTPUT="${NR_OUTPUT:-$WORK_DIR/results}"
MODE=full
for argument in "$@"; do
  case "$argument" in
    --quick) export NR_QUICK=1 ;;
    --tests) MODE=tests ;;
    *) echo "Unknown option: $argument" >&2; exit 2 ;;
  esac
done

LOGS="$WORK_DIR/logs"
mkdir -p "$LOGS"
cd "$WORK_DIR"

# Runs a command in its own process group and kills the whole group after the given seconds
# (./pharo is a shell script that starts the VM as a child).
with_timeout() {
  perl -e 'my $seconds = shift; my $pid = fork; die "fork: $!" unless defined $pid;
    if ($pid == 0) { setpgrp(0, 0); exec @ARGV or die "exec: $!" }
    $SIG{ALRM} = sub { kill "KILL", -$pid; exit 124 };
    alarm $seconds; waitpid($pid, 0); exit($? >> 8)' "$@"
}

# 1. Pharo 14 image and VM ----------------------------------------------------------------------
if [ ! -f Pharo.image ]; then
  if [ -n "${PHARO_DIR:-}" ]; then
    echo "==> Copying the Pharo image and VM of $PHARO_DIR"
    cp "$PHARO_DIR/Pharo.image" "$PHARO_DIR/Pharo.changes" .
    for sources in "$PHARO_DIR"/*.sources; do ln -sf "$sources" .; done
    ln -sfn "$PHARO_DIR/pharo-vm" pharo-vm
    cp "$PHARO_DIR/pharo" pharo
  else
    echo "==> Downloading a Pharo 14 image and VM into $WORK_DIR"
    curl -fsSL https://get.pharo.org/64/140+vm | bash
  fi
fi

# 2. Base image with this repository ---------------------------------------------------------------
if [ "$REINSTALL" = 1 ] || [ ! -f neural-base.image ]; then
  echo "==> Installing $REPO (with $BENCHMARKS_REPO)"
  cat > "$LOGS/install.st" <<EOF
[ Metacello new
	baseline: 'ExtendedHeuristicCompletionBenchmarks';
	repository: '$BENCHMARKS_REPO';
	onConflict: [ :e | e useIncoming ];
	onUpgrade: [ :e | e useIncoming ];
	load.
  Metacello new
	baseline: 'ExtendedHeuristicCompletionBenchmarks';
	repository: '$BENCHMARKS_REPO';
	lock.
  Metacello new
	baseline: 'NeuralReranking';
	repository: '$REPO';
	onConflict: [ :e | e useIncoming ];
	onUpgrade: [ :e | e useIncoming ];
	onLock: [ :e | e honor ];
	load: #( 'default' ) ]
		on: Warning
		do: [ :w | w resume: true ].
((Smalltalk globals includesKey: #CooNeuralExperiment)
	and: [ (Smalltalk globals includesKey: #CooNeuralBenchmarksMessage)
	and: [ Smalltalk globals includesKey: #CooNeuralBenchmarksVariables ] ])
	ifFalse: [ Stdio stderr nextPutAll: 'Install failed'; lf. Smalltalk exitFailure ].
EOF
  cp Pharo.image neural-tmp.image
  cp Pharo.changes neural-tmp.changes
  if ./pharo neural-tmp.image st --save --quit "$LOGS/install.st" > "$LOGS/install.log" 2>&1 \
     && grep -q "finished to load" "$LOGS/install.log"; then
    mv neural-tmp.image neural-base.image
    mv neural-tmp.changes neural-base.changes
  else
    echo "Install failed, see $LOGS/install.log" >&2
    exit 1
  fi
fi

# 3. Tests ------------------------------------------------------------------------------------------
if [ "$MODE" = tests ]; then
  cat > "$LOGS/tests.st" <<'EOF'
| suite result |
suite := TestSuite named: 'NeuralReranking'.
((PackageOrganizer default packageNamed: 'NeuralReranking-Tests') definedClasses
	select: [ :class | class inheritsFrom: TestCase ]) do: [ :class | suite addTests: class suite tests ].
result := suite run.
Stdio stdout nextPutAll: result printString; lf.
(result failures , result errors) do: [ :test | Stdio stdout nextPutAll: 'FAILED ', test printString; lf ].
Stdio stdout flush.
result hasPassed ifFalse: [ Smalltalk exitFailure ].
EOF
  ./pharo neural-base.image st --quit "$LOGS/tests.st"
  exit $?
fi

# 4. Experiment -------------------------------------------------------------------------------------
cp neural-base.image run.image
cp neural-base.changes run.changes
echo "CooNeuralExperiment runFromEnvironment." > "$LOGS/run.st"
echo "==> Running the experiment (log: $LOGS/experiment.log, results: $NR_OUTPUT)"
status=0
with_timeout "$RUN_TIMEOUT" ./pharo run.image st --quit "$LOGS/run.st" > "$LOGS/experiment.log" 2>&1 || status=$?
rm -f run.image run.changes
if [ ! -f "$NR_OUTPUT/summary.md" ]; then
  echo "The experiment failed or timed out (status $status), see $LOGS/experiment.log" >&2
  tail -30 "$LOGS/experiment.log" >&2
  exit 1
fi
echo
cat "$NR_OUTPUT/summary.md"
