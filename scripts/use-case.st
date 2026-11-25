"Prints the completion requests of Figure 1 of the paper (2027-iwst-neural-reranking): for each case, the 10 first
proposals of the Dependency heuristics, once re-ranked, and the pool. The models are read from NR_MODELS, e.g.
    NR_MODELS=neural-bench-p15/results/models ./pharo neural-base.image st --quit ../scripts/use-case.st
(run from the work directory, on a copy of the base image)."
| out models cases |
out := Stdio stdout.
models := (OSEnvironment current at: 'NR_MODELS') asFileReference.
cases := {
  { #message. 'RTree'. 'RTreeCollection'. #balanceRemovedPath:. 'size'. 2 }.
  { #message. 'System-Changes'. 'ChangeRecord'. #sourceCode. 'printString'. 3 }.
  { #message. 'RTree'. 'RTNode'. #ensureBalancePath:. 'value'. 2 }.
  { #variable. 'System-Changes'. 'ChangeRecord'. #fileIn. 'Smalltalk'. 2 } }.
cases do: [ :case | | kind package task reranker base nr node prefix show |
  kind := case first.
  package := PackageOrganizer default packageNamed: case second.
  task := CooNeuralTask forKind: kind.
  reranker := CooNeuralReranker loadFrom: (models / (kind , '-dependency.ston')) fullName.
  base := CooNeuralBenchmarkRunner benchmarkForKind: kind configuration: (CooNeuralBenchmarkConfiguration base: #dependency reranked: false) reranker: nil csvStream: nil.
  nr := CooNeuralBenchmarkRunner benchmarkForKind: kind configuration: (CooNeuralBenchmarkConfiguration base: #dependency reranked: true) reranker: reranker csvStream: nil.
  { base. nr } do: [ :b | b scope: (CoBenchmarkPackage on: package) ].
  reranker prepareForPackage: package.
  node := (task callsitesIn: package) detect: [ :n |
    n methodNode methodClass name = case third and: [ n methodNode selector = case fourth and: [ (task targetOf: n) asString = case fifth ] ] ].
  prefix := case fifth copyFrom: 1 to: case sixth.
  out nextPutAll: '##### '; print: kind; nextPutAll: ' '; nextPutAll: case third; nextPutAll: '>>'; nextPutAll: case fourth; nextPutAll: ' target='; nextPutAll: case fifth; nextPutAll: ' prefix='; nextPutAll: prefix; lf.
  out nextPutAll: 'SOURCE:'; lf; nextPutAll: node methodNode sourceCode; lf.
  out nextPutAll: 'NODE: '; nextPutAll: (node methodNode sourceCode copyFrom: node start to: node stop); lf.
  show := [ :bench :label | | candidates |
    reranker resetLast.
    task setPrefix: prefix on: node.
    [ candidates := bench fetchTopCandidatesFrom: (bench buildCompletionFor: node atPosition: (task positionOf: node)) usingPrefix: prefix ]
      ensure: [ task restore: case fifth on: node ].
    out nextPutAll: label; nextPutAll: ': '.
    candidates do: [ :e | out nextPutAll: e contents asString ] separatedBy: [ out nextPutAll: ' | ' ].
    out lf ].
  show value: base value: 'HEURISTICS'.
  show value: nr value: 'RERANKED'.
  out nextPutAll: 'POOL: '.
  (reranker lastPool ifNil: [ #() ]) do: [ :e | out nextPutAll: e contents asString ] separatedBy: [ out nextPutAll: ' | ' ].
  out lf; lf; flush.
  reranker forgetPackage: package ].
