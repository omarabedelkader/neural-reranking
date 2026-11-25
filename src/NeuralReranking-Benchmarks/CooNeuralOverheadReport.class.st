"
I write what the re-ranking costs on top of the heuristics, for the paper: overhead.md and overhead.tex.

- Time: for each kind of completion and each heuristic configuration, the mean time of a completion
  without and with re-ranking, the extra milliseconds (mean, and median of the request by request
  differences), the tail (p95) without and with, and the time of the re-ranking step alone.
- Memory: what a re-ranker keeps in RAM (the network, the corpus statistics and the index of the package
  being edited, in MB), the memory allocated in addition by a completion (short-lived), the one-time
  indexing of a package, and the heap of the image before and after the benchmarks.

I only read the files of an output directory (results.ston and benchmark/requests-<kind>.csv), so the
report of an experiment already run can be written again:

    CooNeuralOverheadReport writeIn: 'neural-bench/results'.

A request is paired with the same request (package, class, method, expected token, prefix) of the other
configuration, so the differences are request by request.
"
Class {
	#name : 'CooNeuralOverheadReport',
	#superclass : 'Object',
	#instVars : [
		'directory',
		'results',
		'requests'
	],
	#category : 'NeuralReranking-Benchmarks-Experiment',
	#package : 'NeuralReranking-Benchmarks',
	#tag : 'Experiment'
}

{ #category : 'writing' }
CooNeuralOverheadReport class >> writeIn: aDirectory [

	^ self new
		  directory: aDirectory asFileReference;
		  writeAll;
		  yourself
]

{ #category : 'accessing' }
CooNeuralOverheadReport >> baseSummaryOf: aRerankedSummary kind: aKind [

	| baseKey |
	baseKey := (aRerankedSummary at: #key) asString copyReplaceAll: '-nr' with: ''.
	^ (self summariesOf: aKind) detect: [ :each | (each at: #key) asString = baseKey ]
]

{ #category : 'accessing' }
CooNeuralOverheadReport >> directory: aFileReference [

	directory := aFileReference
]

{ #category : 'csv' }
CooNeuralOverheadReport >> fieldsOf: aLine [
	"The fields of a line written by CooNeuralBenchmarkDriver: a quoted field can hold commas and doubled quotes."

	| fields field quoted index char |
	fields := OrderedCollection new.
	field := WriteStream on: (String new: 32).
	quoted := false.
	index := 1.
	[ index <= aLine size ] whileTrue: [
		char := aLine at: index.
		quoted
			ifTrue: [
				char = $"
					ifTrue: [
						(index < aLine size and: [ (aLine at: index + 1) = $" ])
							ifTrue: [
								field nextPut: $".
								index := index + 1 ]
							ifFalse: [ quoted := false ] ]
					ifFalse: [ field nextPut: char ] ]
			ifFalse: [
				char = $"
					ifTrue: [ quoted := true ]
					ifFalse: [
						char = $,
							ifTrue: [
								fields add: field contents.
								field := WriteStream on: (String new: 32) ]
							ifFalse: [ field nextPut: char ] ] ].
		index := index + 1 ].
	fields add: field contents.
	^ fields asArray
]

{ #category : 'formatting' }
CooNeuralOverheadReport >> format: aNumber places: anInteger [

	aNumber ifNil: [ ^ '' ].
	^ aNumber asFloat printShowingDecimalPlaces: anInteger
]

{ #category : 'accessing' }
CooNeuralOverheadReport >> heapOf: aKind [
	"The heap of the image (bytes) before and after the benchmarks of aKind, or nil."

	^ (results at: #heapBytes ifAbsent: [ Dictionary new ]) at: aKind ifAbsent: [ nil ]
]

{ #category : 'accessing' }
CooNeuralOverheadReport >> kinds [

	^ (results at: #results) collect: [ :association | association key ]
]

{ #category : 'loading' }
CooNeuralOverheadReport >> load [

	results := STON fromString: (directory / 'results.ston') contents.
	requests := Dictionary new.
	self kinds do: [ :kind | requests at: kind put: (self loadRequestsOf: kind) ]
]

{ #category : 'loading' }
CooNeuralOverheadReport >> loadRequestsOf: aKind [
	"From configuration key to (request key -> the measures of that request, in order: #(microseconds
	rerankMicroseconds allocatedBytes)). The same request can occur more than once (the same token sent
	twice in a method), its occurrences are paired in order."

	| file byConfiguration |
	byConfiguration := Dictionary new.
	file := directory / 'benchmark' / ('requests-' , aKind , '.csv').
	file exists ifFalse: [ ^ byConfiguration ].
	file readStreamDo: [ :stream |
		stream atEnd ifFalse: [ stream nextLine ].
		[ stream atEnd ] whileFalse: [
			| line fields key |
			line := stream nextLine.
			line isEmptyOrNil ifFalse: [
				fields := self fieldsOf: line.
				fields size >= 12 ifTrue: [
					key := String streamContents: [ :keyStream |
						       (fields copyFrom: 3 to: 7) do: [ :each | keyStream nextPutAll: each ] separatedBy: [ keyStream tab ] ].
					((byConfiguration at: (fields at: 2) ifAbsentPut: [ Dictionary new ])
						 at: key
						 ifAbsentPut: [ OrderedCollection new ]) add: {
							(fields at: 10) asInteger.
							(fields at: 11) asInteger.
							(fields at: 12) asInteger } ] ] ] ].
	^ byConfiguration
]

{ #category : 'formatting' }
CooNeuralOverheadReport >> mb: aByteCount [

	^ self format: (aByteCount ifNil: [ 0 ]) / 1048576.0 places: 2
]

{ #category : 'statistics' }
CooNeuralOverheadReport >> mean: aCollection [

	aCollection isEmpty ifTrue: [ ^ 0 ].
	^ (aCollection inject: 0 into: [ :sum :each | sum + each ]) / aCollection size
]

{ #category : 'formatting' }
CooNeuralOverheadReport >> memoryString: aByteCount [
	"MB, and GB from 1 GB."

	^ aByteCount >= (1024 * 1048576)
		  ifTrue: [ (self format: aByteCount / (1024 * 1048576.0) places: 2) , ' GB' ]
		  ifFalse: [ (self format: aByteCount / 1048576.0 places: 1) , ' MB' ]
]

{ #category : 'formatting' }
CooNeuralOverheadReport >> ms: aMicrosecondCount [

	^ self format: aMicrosecondCount / 1000.0 places: 2
]

{ #category : 'measures' }
CooNeuralOverheadReport >> overheadOf: aRerankedSummary kind: aKind [
	"The measures of a re-ranked configuration against its heuristics, request by request."

	| base reranked baseMeasures rerankedMeasures without with extra rerank extraBytes |
	base := self baseSummaryOf: aRerankedSummary kind: aKind.
	baseMeasures := (requests at: aKind) at: (base at: #key) asString ifAbsent: [ Dictionary new ].
	rerankedMeasures := (requests at: aKind) at: (aRerankedSummary at: #key) asString ifAbsent: [ Dictionary new ].
	without := OrderedCollection new.
	with := OrderedCollection new.
	extra := OrderedCollection new.
	rerank := OrderedCollection new.
	extraBytes := OrderedCollection new.
	rerankedMeasures keysAndValuesDo: [ :key :rerankedList |
		baseMeasures at: key ifPresent: [ :baseList |
			1 to: (baseList size min: rerankedList size) do: [ :index |
				| a b |
				a := baseList at: index.
				b := rerankedList at: index.
				without add: a first.
				with add: b first.
				extra add: b first - a first.
				rerank add: (b at: 2).
				extraBytes add: (b at: 3) - (a at: 3) ] ] ].
	reranked := aRerankedSummary.
	^ Dictionary new
		  at: #kind put: aKind;
		  at: #heuristics put: (base at: #configuration);
		  at: #configuration put: (reranked at: #configuration);
		  at: #pairedRequests put: without size;
		  at: #packages put: (reranked at: #packages ifAbsent: [ #(  ) ]) size;
		  at: #meanWithoutMicroseconds put: (self mean: without);
		  at: #meanWithMicroseconds put: (self mean: with);
		  at: #meanExtraMicroseconds put: (self mean: extra);
		  at: #extraPercent put: ((self mean: without) = 0
				   ifTrue: [ 0 ]
				   ifFalse: [ 100.0 * (self mean: extra) / (self mean: without) ]);
		  at: #medianExtraMicroseconds put: (self percentile: 0.5 of: extra);
		  at: #p95WithoutMicroseconds put: (self percentile: 0.95 of: without);
		  at: #p95WithMicroseconds put: (self percentile: 0.95 of: with);
		  at: #meanRerankMicroseconds put: (self mean: rerank);
		  at: #p95RerankMicroseconds put: (self percentile: 0.95 of: rerank);
		  at: #p99RerankMicroseconds put: (self percentile: 0.99 of: rerank);
		  at: #meanExtraAllocatedBytes put: (self mean: extraBytes);
		  at: #modelBytes put: (reranked at: #modelBytes ifAbsent: [ 0 ]);
		  at: #statisticsBytes put: (reranked at: #statisticsBytes ifAbsent: [ 0 ]);
		  at: #indexBytes put: (reranked at: #meanIndexBytes ifAbsent: [ 0 ]);
		  at: #heldBytes
		  put: (reranked at: #modelBytes ifAbsent: [ 0 ]) + (reranked at: #statisticsBytes ifAbsent: [ 0 ])
			  + (reranked at: #meanIndexBytes ifAbsent: [ 0 ]);
		  at: #indexMilliseconds put: (reranked at: #meanIndexMilliseconds ifAbsent: [ 0 ]);
		  at: #parameters put: (reranked at: #modelParameters ifAbsent: [ 0 ]);
		  yourself
]

{ #category : 'measures' }
CooNeuralOverheadReport >> overheads [
	"One dictionary per kind and re-ranked configuration (see #overheadOf:kind:)."

	results ifNil: [ self load ].
	^ self kinds flatCollect: [ :kind |
		  ((self summariesOf: kind) select: [ :each | each includesKey: #modelBytes ]) collect: [ :each |
			  self overheadOf: each kind: kind ] ]
]

{ #category : 'statistics' }
CooNeuralOverheadReport >> percentile: aFraction of: aCollection [
	"As CooNeuralBenchmarkResult>>#percentile:of:."

	| sorted index |
	aCollection isEmpty ifTrue: [ ^ 0 ].
	sorted := aCollection asArray sort.
	index := (aFraction * sorted size) ceiling max: 1.
	^ sorted at: (index min: sorted size)
]

{ #category : 'formatting' }
CooNeuralOverheadReport >> signed: aFormattedNumber [
	"'+1.25' for an increase, '-0.07' for a decrease."

	^ (aFormattedNumber beginsWith: '-')
		  ifTrue: [ aFormattedNumber ]
		  ifFalse: [ '+' , aFormattedNumber ]
]

{ #category : 'accessing' }
CooNeuralOverheadReport >> summariesOf: aKind [

	^ ((results at: #results) detect: [ :association | association key = aKind ]) value
]

{ #category : 'writing' }
CooNeuralOverheadReport >> write: aString to: aFileReference [

	aFileReference ensureDelete.
	aFileReference writeStreamDo: [ :stream | stream nextPutAll: aString ]
]

{ #category : 'writing' }
CooNeuralOverheadReport >> writeAll [

	| overheads |
	overheads := self overheads.
	self write: (String streamContents: [ :stream | self writeMarkdown: overheads on: stream ]) to: directory / 'overhead.md'.
	self write: (String streamContents: [ :stream | self writeLatex: overheads on: stream ]) to: directory / 'overhead.tex'
]

{ #category : 'writing' }
CooNeuralOverheadReport >> writeDeployedMarkdown: someOverheads on: aStream [
	"A message and a variable re-ranker of the same heuristics, as they would be installed together:
	the corpus statistics are one object shared by all the re-rankers, so they are counted once."

	| bases |
	self kinds size > 1 ifFalse: [ ^ self ].
	bases := OrderedCollection new.
	someOverheads do: [ :each | (bases includes: (each at: #heuristics)) ifFalse: [ bases add: (each at: #heuristics) ] ].
	aStream
		nextPutAll: 'Installed together, a message and a variable re-ranker of the same heuristics hold ';
		nextPutAll: '(the corpus statistics are shared, counted once): '.
	bases
		do: [ :base |
			| ofBase |
			ofBase := someOverheads select: [ :each | (each at: #heuristics) = base ].
			aStream
				nextPutAll: base;
				nextPutAll: ' ';
				nextPutAll: (self mb:
							 (ofBase inject: 0 into: [ :sum :each | sum + (each at: #modelBytes) + (each at: #indexBytes) ])
							 + (ofBase inject: 0 into: [ :max :each | max max: (each at: #statisticsBytes) ]));
				nextPutAll: ' MB' ]
		separatedBy: [ aStream nextPutAll: ', ' ].
	aStream
		nextPutAll: '.';
		lf;
		lf
]

{ #category : 'writing' }
CooNeuralOverheadReport >> writeLatex: someOverheads on: aStream [

	aStream
		nextPutAll: '% Time added by the re-ranking (milliseconds per completion)';
		lf;
		nextPutAll: '\begin{tabular}{llrrrrrrrr}';
		lf;
		nextPutAll: '\hline';
		lf;
		nextPutAll:
			'Kind & Heuristics & Without & With & Extra & Extra (\%) & Median extra & p95 without & p95 with & Re-ranking step \\';
		lf;
		nextPutAll: '\hline';
		lf.
	someOverheads do: [ :each |
		aStream
			nextPutAll: (each at: #kind);
			nextPutAll: ' & ';
			nextPutAll: (each at: #heuristics);
			nextPutAll: ' & ';
			nextPutAll: (self ms: (each at: #meanWithoutMicroseconds));
			nextPutAll: ' & ';
			nextPutAll: (self ms: (each at: #meanWithMicroseconds));
			nextPutAll: ' & ';
			nextPutAll: (self signed: (self ms: (each at: #meanExtraMicroseconds)));
			nextPutAll: ' & ';
			nextPutAll: (self format: (each at: #extraPercent) places: 1);
			nextPutAll: ' & ';
			nextPutAll: (self ms: (each at: #medianExtraMicroseconds));
			nextPutAll: ' & ';
			nextPutAll: (self ms: (each at: #p95WithoutMicroseconds));
			nextPutAll: ' & ';
			nextPutAll: (self ms: (each at: #p95WithMicroseconds));
			nextPutAll: ' & ';
			nextPutAll: (self ms: (each at: #meanRerankMicroseconds));
			nextPutAll: ' \\';
			lf ].
	aStream
		nextPutAll: '\hline';
		lf;
		nextPutAll: '\end{tabular}';
		lf;
		lf;
		nextPutAll: '% Memory of the re-rankers (MB)';
		lf;
		nextPutAll: '\begin{tabular}{llrrrrrrr}';
		lf;
		nextPutAll: '\hline';
		lf;
		nextPutAll:
			'Kind & Heuristics & Parameters & Network & Corpus stat. & Package index & Held in RAM & Alloc./completion & Indexing (ms) \\';
		lf;
		nextPutAll: '\hline';
		lf.
	someOverheads do: [ :each |
		aStream
			nextPutAll: (each at: #kind);
			nextPutAll: ' & ';
			nextPutAll: (each at: #heuristics);
			nextPutAll: ' & ';
			print: (each at: #parameters);
			nextPutAll: ' & ';
			nextPutAll: (self mb: (each at: #modelBytes));
			nextPutAll: ' & ';
			nextPutAll: (self mb: (each at: #statisticsBytes));
			nextPutAll: ' & ';
			nextPutAll: (self mb: (each at: #indexBytes));
			nextPutAll: ' & ';
			nextPutAll: (self mb: (each at: #heldBytes));
			nextPutAll: ' & ';
			nextPutAll: (self signed: (self mb: (each at: #meanExtraAllocatedBytes)));
			nextPutAll: ' & ';
			nextPutAll: (self format: (each at: #indexMilliseconds) places: 1);
			nextPutAll: ' \\';
			lf ].
	aStream
		nextPutAll: '\hline';
		lf;
		nextPutAll: '\end{tabular}';
		lf
]

{ #category : 'writing' }
CooNeuralOverheadReport >> writeMarkdown: someOverheads on: aStream [

	aStream
		nextPutAll: '# What the re-ranking costs';
		lf;
		lf.
	someOverheads isEmpty ifFalse: [
		aStream
			print: (someOverheads first at: #packages);
			nextPutAll: ' test packages; requests per configuration: '.
		self kinds
			do: [ :kind |
				(someOverheads detect: [ :each | (each at: #kind) = kind ] ifNone: [ nil ]) ifNotNil: [ :each |
					aStream
						print: (each at: #pairedRequests);
						nextPutAll: ' ';
						nextPutAll: kind ] ]
			separatedBy: [ aStream nextPutAll: ', ' ].
		aStream
			nextPutAll: '. Each request is compared with the same request completed by the heuristics alone.';
			lf;
			lf ].
	aStream
		nextPutAll: '## Time added to a completion (ms)';
		lf;
		lf;
		nextPutAll:
			'| Kind | Heuristics | Without re-ranking (mean) | With re-ranking (mean) | Extra (mean) | Extra (%) | Extra (median, per request) | p95 without | p95 with | Re-ranking step (mean / p95 / p99) |';
		lf;
		nextPutAll: '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|';
		lf.
	someOverheads do: [ :each |
		aStream
			nextPutAll: '| ';
			nextPutAll: (each at: #kind);
			nextPutAll: ' | ';
			nextPutAll: (each at: #heuristics);
			nextPutAll: ' | ';
			nextPutAll: (self ms: (each at: #meanWithoutMicroseconds));
			nextPutAll: ' | ';
			nextPutAll: (self ms: (each at: #meanWithMicroseconds));
			nextPutAll: ' | ';
			nextPutAll: (self signed: (self ms: (each at: #meanExtraMicroseconds)));
			nextPutAll: ' | ';
			nextPutAll: (self format: (each at: #extraPercent) places: 1);
			nextPutAll: ' | ';
			nextPutAll: (self ms: (each at: #medianExtraMicroseconds));
			nextPutAll: ' | ';
			nextPutAll: (self ms: (each at: #p95WithoutMicroseconds));
			nextPutAll: ' | ';
			nextPutAll: (self ms: (each at: #p95WithMicroseconds));
			nextPutAll: ' | ';
			nextPutAll: (self ms: (each at: #meanRerankMicroseconds));
			nextPutAll: ' / ';
			nextPutAll: (self ms: (each at: #p95RerankMicroseconds));
			nextPutAll: ' / ';
			nextPutAll: (self ms: (each at: #p99RerankMicroseconds));
			nextPutAll: ' |';
			lf ].
	aStream
		lf;
		nextPutAll:
			'A completion: building it, fetching the candidates and, re-ranked, scoring the pool and answering the 10 first. ';
		nextPutAll:
			'*Extra* includes everything the re-ranking adds (a larger pool, the features, the network); the *re-ranking step* is the features and the network alone.';
		lf;
		lf;
		nextPutAll: '## Memory of the re-rankers (MB)';
		lf;
		lf;
		nextPutAll:
			'| Kind | Heuristics | Parameters | Network | Corpus statistics | Package index (mean) | Held in RAM | Allocated in addition per completion (mean) | Indexing a package (ms, once) |';
		lf;
		nextPutAll: '|---|---|---:|---:|---:|---:|---:|---:|---:|';
		lf.
	someOverheads do: [ :each |
		aStream
			nextPutAll: '| ';
			nextPutAll: (each at: #kind);
			nextPutAll: ' | ';
			nextPutAll: (each at: #heuristics);
			nextPutAll: ' | ';
			print: (each at: #parameters);
			nextPutAll: ' | ';
			nextPutAll: (self mb: (each at: #modelBytes));
			nextPutAll: ' | ';
			nextPutAll: (self mb: (each at: #statisticsBytes));
			nextPutAll: ' | ';
			nextPutAll: (self mb: (each at: #indexBytes));
			nextPutAll: ' | ';
			nextPutAll: (self mb: (each at: #heldBytes));
			nextPutAll: ' | ';
			nextPutAll: (self signed: (self mb: (each at: #meanExtraAllocatedBytes)));
			nextPutAll: ' | ';
			nextPutAll: (self format: (each at: #indexMilliseconds) places: 1);
			nextPutAll: ' |';
			lf ].
	aStream
		lf;
		nextPutAll:
			'*Held in RAM*: what stays in memory while completing in a package: the network, the corpus statistics and the index of that package. ';
		nextPutAll:
			'*Allocated in addition*: short-lived objects created by a completion, collected by the garbage collector, not held.';
		lf;
		lf.
	self writeDeployedMarkdown: someOverheads on: aStream.
	self kinds do: [ :kind |
		(self heapOf: kind) ifNotNil: [ :heap |
			aStream
				nextPutAll: 'Heap of the image, ';
				nextPutAll: kind;
				nextPutAll: ' benchmarks: ';
				nextPutAll: (self memoryString: heap first);
				nextPutAll: ' before, ';
				nextPutAll: (self memoryString: heap second);
				nextPutAll: ' after.';
				lf ] ]
]
