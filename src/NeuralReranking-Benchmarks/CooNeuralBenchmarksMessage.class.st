"
I am CooStaticBenchmarksMessage (HeuristicCompletion-Benchmarks) with finer measures: every request
is measured by my CooNeuralBenchmarkDriver (microseconds, allocated bytes, rank, rank in the pool of
the re-ranker), and my builder can be a CooNeuralRerankingResultSetBuilder.

All the reports of my superclass (accuracy, MRR, NDCG, time and memory tables, LaTeX, inspector) work.
The time I log there is in milliseconds (with decimals), the memory in allocated bytes.

Alone on one package:

    (CooNeuralBenchmarkRunner benchmarkForKind: #message
        configuration: (CooNeuralBenchmarkConfiguration base: #semantics reranked: true)
        reranker: (CooNeuralReranker loadFrom: 'models/message-semantics.ston'))
            package: (PackageOrganizer default packageNamed: 'NECompletion');
            run;
            inspect.

To compare the six configurations request by request, see CooNeuralBenchmarkRunner and CooNeuralExperiment.
"
Class {
	#name : 'CooNeuralBenchmarksMessage',
	#superclass : 'CooStaticBenchmarksMessage',
	#instVars : [
		'driver',
		'package',
		'callsitesPerPackage',
		'seed'
	],
	#category : 'NeuralReranking-Benchmarks-Core',
	#package : 'NeuralReranking-Benchmarks',
	#tag : 'Core'
}

{ #category : 'benchmarks' }
CooNeuralBenchmarksMessage >> benchCallsite: aMessageNode atPosition: aPosition [

	driver benchAllPrefixesOf: aMessageNode position: aPosition for: self
]

{ #category : 'accessing' }
CooNeuralBenchmarksMessage >> callsitesPerPackage: anIntegerOrNil [

	callsitesPerPackage := anIntegerOrNil
]

{ #category : 'accessing' }
CooNeuralBenchmarksMessage >> driver [

	^ driver
]

{ #category : 'accessing' }
CooNeuralBenchmarksMessage >> driver: aDriver [

	driver := aDriver
]

{ #category : 'benchmarks' }
CooNeuralBenchmarksMessage >> findCompletionIndexFor: aSelector inCandidates: candidates [

	^ driver task rankOf: aSelector in: candidates
]

{ #category : 'accessing' }
CooNeuralBenchmarksMessage >> package: aPackage [

	package := aPackage.
	scope := CoBenchmarkPackage on: aPackage
]

{ #category : 'accessing' }
CooNeuralBenchmarksMessage >> result [

	^ driver result
]

{ #category : 'running' }
CooNeuralBenchmarksMessage >> run [
	"Benchmark the call sites of my package only (see CooNeuralBenchmarkRunner to compare configurations)."

	CooNeuralBenchmarkRunner new
		runAlone: self
		package: package
		callsitesPerPackage: callsitesPerPackage
		seed: (seed ifNil: [ 42 ])
]

{ #category : 'accessing' }
CooNeuralBenchmarksMessage >> seed: anInteger [

	seed := anInteger
]
