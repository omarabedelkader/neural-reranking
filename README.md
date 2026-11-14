# neural-reranking

A small neural re-ranker for Pharo code completion, trained, validated and tested on Pharo packages,
and benchmarked with [HeuristicCompletion-Benchmarks](https://github.com/omarabedelkader/HeuristicCompletion-Benchmarks)
on six configurations, with the accuracy, the **time** and the **memory** of every completion.

| Configuration | Candidates (heuristics) | Re-ranked |
|---|---|---|
| Baseline | flat: all the selectors / all the globals of the image | no |
| Baseline + Re-ranking | same | yes |
| Semantics | the default Complishon heuristics (self, super, typed receivers, literals, ..., then all selectors; local, workspace, instance variables, then globals) | no |
| Semantics + Re-ranking | same | yes |
| Dependency | Semantics, plus the selectors / classes of the direct package dependencies before the global fallback | no |
| Dependency + Re-ranking | same | yes |

Both kinds of completion of the benchmarks are covered: **messages** (selectors) and **variables** (class names
and other globals), each with prefixes of 2 to 8 characters, as `CooStaticBenchmarksMessage` and
`CooStaticBenchmarksVariables` do.

Everything is plain Pharo: features, network, training (backpropagation and Adam written in Smalltalk),
inference and benchmarks. No plugin, no Python, so the re-ranker is measured inside the image exactly like
the heuristics it re-ranks.

## Install

```smalltalk
Metacello new
  baseline: 'NeuralReranking';
  repository: 'github://omarabedelkader/neural-reranking:main/src';
  load.
```

It loads `HeuristicCompletion-Benchmarks` too (groups: `Core`, `Training`, `Benchmarks`, `Tests`; `default` is all).
Tested on Pharo 14.

## Run the experiment

```bash
scripts/run-neural-benchmarks.sh --quick   # a few minutes: to try the pipeline
scripts/run-neural-benchmarks.sh           # the default experiment (about an hour)
scripts/run-neural-benchmarks.sh --tests   # the SUnit tests only
```

The script downloads a Pharo 14 image and VM into `neural-bench/` (or copies the ones of `PHARO_DIR`), installs this
checkout and `HeuristicCompletion-Benchmarks` (the checkout next to this one when there is one, GitHub otherwise),
runs the experiment and prints `neural-bench/results/summary.md`.

In an image:

```smalltalk
CooNeuralExperiment quick run.
CooNeuralExperiment new outputDirectory: '/tmp/neural-results'; run.
(CooNeuralExperiment new testPackageNames: #('NECompletion' 'Spec2-Core'); yourself) run.
```

### What the experiment does

1. **Split** (`CooNeuralPackageSplit`): the packages of the image with 30 to 4000 methods are grouped by project
   (first segment of their name: `Spec2-Core`, `Spec2-Tests`, ... are all `Spec2`) and the projects are drawn into
   training (~70%), validation (~15%) and test (~15%) packages with the seed. A project is never in two sets, so a
   package is never tested on a model that was trained on its tests or its core. Given test packages
   (`NR_TEST_PACKAGES`), their projects are removed from training and validation.
2. **Corpus statistics** (`CooNeuralCorpusStatistics`), on the training packages only: how often each selector is
   sent, sent to each kind of receiver (`self`, `var:aStream`, `global:OrderedCollection`, `message:new`, ...), and how
   often each global is referenced.
3. **Training** (`CooNeuralDatasetBuilder`, `CooNeuralTrainer`), for each kind of completion and each heuristic
   configuration (6 networks): the call sites of the training packages are completed with that configuration, the
   first 20 candidates (the *pool*) become a training query when the expected token is among them. The network is
   trained with a listwise softmax loss and Adam, evaluated after every epoch on the validation packages, and the best
   epoch is kept (early stopping). The models are saved in `results/models/<kind>-<configuration>.ston`.
4. **Test** (`CooNeuralBenchmarkRunner`): on the test packages, every request (call site x prefix) is completed by
   the six configurations, one after the other; the configuration that starts changes at every request so none of
   them always warms up (or profits from) the caches.
5. **Reports** (`CooNeuralReport`).

With the same seed and the same base image (`neural-bench/neural-base.image`), two runs give the same accuracy
numbers. A rebuilt image can list some candidates of the heuristics in another order beyond rank 10 (hashed
collections), which moves the re-ranked MRR by about 0.001; the times always vary a little.

### The re-ranker

For one completion request, the heuristics give their first 20 candidates; the re-ranker computes features for each
candidate, scores them with the network and answers them by decreasing score (`CooNeuralReranker`).

Features of a message candidate (`CooNeuralMessageFeatureExtractor`): its rank in the list of the heuristics, the prefix
and remaining sizes, its arity, how often it is sent in the training corpus and to this kind of receiver, how often it
is sent in the rest of the package, whether the package implements it, whether the class understands it, the kind of
receiver, and the fetcher (heuristic) that proposed it.
Features of a variable candidate (`CooNeuralVariableFeatureExtractor`): its rank, the prefix and remaining sizes, how
often it is referenced in the corpus, in the rest of the package and of the class, whether it is defined in the package
or in the same project, the overlap of its sub-words with the class name, whether it is a class or a test class,
whether the method is in a test class, and the fetcher.

The network (`CooNeuralMLP`) is

```
x = [ standardized features ; one-hot of the fetcher ; e(candidate) ; e(candidate) * e(context) ]
score = w2 . relu(W1 x + b1) + b2
```

where `e(...)` is the mean of embeddings of hashed sub-words (`nextPutAll:` gives `next`, `put`, `all`; the context is
the receiver, the class and the method being written). With the defaults (16 hidden units, embeddings of 8 in 4096
buckets) it has about 34 000 parameters.

**No leakage**: a static benchmark completes methods that are already written, so the counts of the package exclude
the method being completed (`CooNeuralPackageIndex`), the corpus statistics come from the training packages only, and
when the training queries are extracted the counts of their own method are removed from the corpus statistics
(leave-one-out). The tests check it (`CooNeuralFeatureTest`).

### Measures

For each kind of completion and configuration (`summary.md`, `summary.csv`, `summary.tex`):

- **MRR@10**, Recall@1/3/5/10, MRR@10 per prefix size, wins / ties / losses of each re-ranked configuration against its
  heuristics, request by request;
- **time** of a completion in microseconds (mean, median, p95, p99): building the completion, fetching and re-ranking
  the 10 first candidates; and the re-ranking alone;
- **memory**: the bytes allocated during the completion (`Smalltalk vm parameterAt: 34`), the memory held by the
  network and by the corpus statistics, and by the index of a package (`CooNeuralFootprint`), the time to index a
  package (once, before its first completion, so it is reported apart), and the heap of the image before and after
  the benchmarks;
- how often the expected token is in the pool (the best a re-ranker of the pool can do).

The benchmarks are subclasses of `CooStaticBenchmarksMessage` and `CooStaticBenchmarksVariables`, so the usual reports
of HeuristicCompletion-Benchmarks (accuracy, MRR, NDCG, time and memory tables, LaTeX, inspector) are there too:
`results/benchmark/<kind>-<configuration>.txt`.

### Output

```
results/
  summary.md  summary.csv  summary.tex     all the tables
  prefix-mrr.csv  packages.csv             MRR@10 per prefix size / per test package
  split.md  split.ston                     the packages of each set
  models/<kind>-<configuration>.ston       the 6 trained re-rankers
  training/<kind>-<configuration>.csv      validation curve (loss, MRR, recall per epoch)
  benchmark/requests-<kind>.csv            every request: rank, rank in the pool, microseconds, allocated bytes
  benchmark/<kind>-<configuration>.txt     report of HeuristicCompletion-Benchmarks
  results.ston  experiment.log
```

### Options

| Variable | Default | |
|---|---|---|
| `NR_QUICK` | 0 | 1: small experiment (8/3/3 packages, 25-30 call sites per package, 4 epochs) |
| `NR_OUTPUT` | `neural-bench/results` | results directory |
| `NR_SEED` | 42 | split, sampling, initialization, shuffling |
| `NR_TEST_PACKAGES` | | comma-separated test packages (their projects leave training and validation) |
| `NR_TRAIN_PACKAGES`, `NR_VALIDATION_PACKAGES` | | explicit package lists |
| `NR_MAX_TRAIN_PACKAGES`, `NR_MAX_VALIDATION_PACKAGES`, `NR_MAX_TEST_PACKAGES` | 40, 10, 15 | packages drawn from each set (0: all) |
| `NR_TRAIN_CALLSITES`, `NR_VALIDATION_CALLSITES`, `NR_TEST_CALLSITES` | 50, 50, 200 | call sites drawn per package (0: all) |
| `NR_KINDS` | `message,variable` | |
| `NR_CONFIGURATIONS` | `baseline,semantics,dependency` | |
| `NR_POOL` | 20 | candidates given to the re-ranker |
| `NR_HIDDEN`, `NR_EMBEDDING`, `NR_BUCKETS` | 16, 8, 4096 | network |
| `NR_EPOCHS`, `NR_BATCH`, `NR_LEARNING_RATE`, `NR_PATIENCE` | 8, 16, 0.005, 3 | training |
| `NR_MODELS`, `NR_REUSE_MODELS` | `results/models`, 0 | 1: load the saved models instead of training |

## Use a re-ranker elsewhere

`CooNeuralRerankingResultSetBuilder` decorates any Complishon builder, so a trained re-ranker can be given to any
benchmark of HeuristicCompletion-Benchmarks:

```smalltalk
reranker := CooNeuralReranker loadFrom: 'neural-bench/results/models/message-semantics.ston'.
(CooStaticBenchmarksMessage new
    scope: (CoBenchmarkPackage on: (PackageOrganizer default packageNamed: 'NECompletion'));
    builder: (CooNeuralRerankingResultSetBuilder
        on: (CooNeuralHeuristics builderFor: #semantics kind: #message)
        reranker: reranker);
    run) inspect.
```

or run one configuration alone with the finer measures:

```smalltalk
(CooNeuralBenchmarkRunner
    benchmarkForKind: #message
    configuration: (CooNeuralBenchmarkConfiguration base: #semantics reranked: true)
    reranker: reranker)
        package: (PackageOrganizer default packageNamed: 'NECompletion');
        run;
        inspect.
```

## Layout

| Package | |
|---|---|
| `NeuralReranking-Core` | text utilities, package index, corpus statistics, feature extractors, the network, the re-ranker and the builder decorator, the heuristic configurations, the tasks (message / variable call sites) |
| `NeuralReranking-Training` | package split, dataset extraction, trainer |
| `NeuralReranking-Benchmarks` | the six configurations, the benchmarks (subclasses of HeuristicCompletion-Benchmarks), the runner, results, footprint, experiment and reports |
| `NeuralReranking-Tests` | tests, among them a finite-difference check of the gradients and the leakage checks |
