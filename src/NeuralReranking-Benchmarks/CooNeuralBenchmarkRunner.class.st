"
I run several configurations (CooNeuralBenchmarkConfiguration) of one kind of completion on the same
packages, request by request: for every call site and every prefix, all the configurations complete the
same request one after the other. The configuration that starts changes from one request to the next,
so no configuration always pays (or always profits from) warming up the caches of the image.

Before the first request of a package, the re-rankers index the package; that time and the memory of the
index are recorded apart, as one-time costs (CooNeuralBenchmarkResult>>#addIndexMicroseconds:bytes:).

    runner := CooNeuralBenchmarkRunner new
        kind: #message;
        configurations: CooNeuralBenchmarkConfiguration all;
        rerankers: aDictionaryFromBaseNameToReranker;
        callsitesPerPackage: 200;
        yourself.
    runner run: somePackages.
    runner results.
"
Class {
	#name : 'CooNeuralBenchmarkRunner',
	#superclass : 'Object',
	#instVars : [
		'kind',
		'task',
		'configurations',
		'rerankers',
		'drivers',
		'benchmarks',
		'callsitesPerPackage',
		'seed',
		'csvStream',
		'logBlock',
		'requestCount'
	],
	#category : 'NeuralReranking-Benchmarks-Core',
	#package : 'NeuralReranking-Benchmarks',
	#tag : 'Core'
}

{ #category : 'instance creation' }
CooNeuralBenchmarkRunner class >> benchmarkClassForKind: aKind [

	aKind asSymbol = #message ifTrue: [ ^ CooNeuralBenchmarksMessage ].
	aKind asSymbol = #variable ifTrue: [ ^ CooNeuralBenchmarksVariables ].
	^ self error: 'Unknown completion kind: ' , aKind printString
]

{ #category : 'instance creation' }
CooNeuralBenchmarkRunner class >> benchmarkForKind: aKind configuration: aConfiguration reranker: aRerankerOrNil [

	^ self
		  benchmarkForKind: aKind
		  configuration: aConfiguration
		  reranker: aRerankerOrNil
		  csvStream: nil
]

{ #category : 'instance creation' }
CooNeuralBenchmarkRunner class >> benchmarkForKind: aKind configuration: aConfiguration reranker: aRerankerOrNil csvStream: aStreamOrNil [

	| result |
	result := CooNeuralBenchmarkResult kind: aKind configuration: aConfiguration.
	aRerankerOrNil ifNotNil: [
		result
			modelBytes: (CooNeuralFootprint bytesOf: aRerankerOrNil model)
			statisticsBytes: (CooNeuralFootprint bytesOf: aRerankerOrNil extractor statistics)
			parameters: aRerankerOrNil model numberOfParameters ].
	^ (self benchmarkClassForKind: aKind) new
		  name: aConfiguration name;
		  builder: (aConfiguration builderFor: aKind reranker: aRerankerOrNil);
		  driver: (CooNeuralBenchmarkDriver new
				   task: (CooNeuralTask forKind: aKind);
				   configuration: aConfiguration;
				   reranker: aRerankerOrNil;
				   result: result;
				   csvStream: aStreamOrNil;
				   yourself);
		  yourself
]

{ #category : 'accessing' }
CooNeuralBenchmarkRunner >> benchmarks [

	^ benchmarks
]

{ #category : 'accessing' }
CooNeuralBenchmarkRunner >> callsitesPerPackage: anIntegerOrNil [

	callsitesPerPackage := anIntegerOrNil
]

{ #category : 'accessing' }
CooNeuralBenchmarkRunner >> configurations: aCollection [

	configurations := aCollection asArray
]

{ #category : 'accessing' }
CooNeuralBenchmarkRunner >> csvStream: aStreamOrNil [

	csvStream := aStreamOrNil
]

{ #category : 'initialization' }
CooNeuralBenchmarkRunner >> initialize [

	super initialize.
	seed := 42.
	callsitesPerPackage := nil.
	rerankers := Dictionary new.
	requestCount := 0
]

{ #category : 'accessing' }
CooNeuralBenchmarkRunner >> kind: aKind [

	kind := aKind asSymbol.
	task := CooNeuralTask forKind: kind
]

{ #category : 'logging' }
CooNeuralBenchmarkRunner >> log: aString [

	logBlock ifNotNil: [ logBlock value: aString ]
]

{ #category : 'accessing' }
CooNeuralBenchmarkRunner >> logBlock: aBlock [

	logBlock := aBlock
]

{ #category : 'running' }
CooNeuralBenchmarkRunner >> orderFor: aRequestNumber [

	| size |
	size := benchmarks size.
	^ (0 to: size - 1) collect: [ :offset | offset + aRequestNumber \\ size + 1 ]
]

{ #category : 'running' }
CooNeuralBenchmarkRunner >> prepare: aDriver for: aPackage [

	aDriver packageName: aPackage name.
	aDriver reranker ifNotNil: [ :reranker |
		| start index |
		start := Time microsecondClockValue.
		index := reranker prepareForPackage: aPackage.
		aDriver result
			addIndexMicroseconds: Time microsecondClockValue - start
			bytes: (CooNeuralFootprint bytesOf: index) ]
]

{ #category : 'accessing' }
CooNeuralBenchmarkRunner >> rerankers: aDictionary [
	"From base configuration name (#baseline, #semantics, #dependency) to the CooNeuralReranker trained on it."

	rerankers := aDictionary
]

{ #category : 'accessing' }
CooNeuralBenchmarkRunner >> results [

	^ benchmarks collect: [ :benchmark | benchmark result ]
]

{ #category : 'running' }
CooNeuralBenchmarkRunner >> run: aCollectionOfPackages [

	benchmarks ifNil: [ self setUp ].
	aCollectionOfPackages doWithIndex: [ :package :index |
		self log: kind , ' ' , index printString , '/' , aCollectionOfPackages size printString , ' ' , package name.
		self runPackage: package ]
]

{ #category : 'running' }
CooNeuralBenchmarkRunner >> runAlone: aBenchmark package: aPackage callsitesPerPackage: aMaximumOrNil seed: aSeed [

	kind := aBenchmark driver task kind.
	task := aBenchmark driver task.
	benchmarks := { aBenchmark }.
	drivers := { aBenchmark driver }.
	callsitesPerPackage := aMaximumOrNil.
	seed := aSeed.
	self runPackage: aPackage
]

{ #category : 'running' }
CooNeuralBenchmarkRunner >> runPackage: aPackage [

	| callsites before |
	drivers do: [ :driver | self prepare: driver for: aPackage ].
	benchmarks do: [ :benchmark | benchmark scope: (CoBenchmarkPackage on: aPackage) ].
	callsites := task
		             sample: (task callsitesIn: aPackage)
		             max: callsitesPerPackage
		             seed: seed
		             salt: aPackage name.
	before := requestCount.
	callsites do: [ :node |
		| target position |
		target := task targetOf: node.
		position := task positionOf: node.
		2 to: (task maxPrefixSizeFor: target) do: [ :size |
			(self orderFor: requestCount) do: [ :index |
				(drivers at: index)
					bench: (benchmarks at: index)
					node: node
					target: target
					prefixSize: size
					position: position ].
			requestCount := requestCount + 1 ] ].
	drivers do: [ :driver | driver reranker ifNotNil: [ :reranker | reranker forgetPackage: aPackage ] ].
	self log: '  ' , callsites size printString , ' call sites, ' , (requestCount - before) printString , ' requests'
]

{ #category : 'accessing' }
CooNeuralBenchmarkRunner >> seed: anInteger [

	seed := anInteger
]

{ #category : 'running' }
CooNeuralBenchmarkRunner >> setUp [

	benchmarks := configurations collect: [ :configuration |
		              self class
			              benchmarkForKind: kind
			              configuration: configuration
			              reranker: (configuration isReranked
					               ifTrue: [ rerankers at: configuration base ]
					               ifFalse: [ nil ])
			              csvStream: csvStream ].
	drivers := benchmarks collect: [ :benchmark | benchmark driver ]
]
