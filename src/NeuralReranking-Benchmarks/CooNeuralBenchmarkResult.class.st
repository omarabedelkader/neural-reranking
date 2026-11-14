"
I collect the measures of one configuration for one kind of completion over all the test requests:
for every request, the rank of the expected token in the first ten proposals (0 when absent), its rank in
the pool given to the re-ranker (re-ranked configurations only, -1 otherwise), the completion time in
microseconds (building the completion, fetching and re-ranking the candidates), the re-ranking time alone
and the bytes allocated during the completion (VM parameter 34).

I also keep the one-time costs of the re-ranker: the time to index every test package, and the memory of
the network, of the corpus statistics and of a package index.

The requests are recorded in the same order for all the configurations of a kind, so two results can be
compared request by request (#comparisonWith:).
"
Class {
	#name : 'CooNeuralBenchmarkResult',
	#superclass : 'Object',
	#instVars : [
		'kind',
		'configuration',
		'ranks',
		'poolRanks',
		'prefixSizes',
		'microseconds',
		'rerankMicroseconds',
		'allocatedBytes',
		'failures',
		'indexMicroseconds',
		'indexBytes',
		'modelBytes',
		'statisticsBytes',
		'modelParameters',
		'packageNames',
		'requestPackages',
		'currentPackageName'
	],
	#category : 'NeuralReranking-Benchmarks-Core',
	#package : 'NeuralReranking-Benchmarks',
	#tag : 'Core'
}

{ #category : 'instance creation' }
CooNeuralBenchmarkResult class >> kind: aKind configuration: aConfiguration [

	^ self new
		  setKind: aKind configuration: aConfiguration;
		  yourself
]

{ #category : 'recording' }
CooNeuralBenchmarkResult >> addIndexMicroseconds: anInteger bytes: aByteCount [

	indexMicroseconds add: anInteger.
	indexBytes add: aByteCount
]

{ #category : 'recording' }
CooNeuralBenchmarkResult >> addPackageName: aString [
	"The following requests are in the package named aString."

	currentPackageName := aString.
	(packageNames includes: aString) ifFalse: [ packageNames add: aString ]
]

{ #category : 'recording' }
CooNeuralBenchmarkResult >> addRank: aRank prefixSize: aSize poolRank: aPoolRank microseconds: aTime rerankMicroseconds: aRerankTime allocatedBytes: aByteCount failed: aBoolean [

	ranks add: aRank.
	requestPackages add: currentPackageName.
	prefixSizes add: aSize.
	poolRanks add: aPoolRank.
	microseconds add: aTime.
	rerankMicroseconds add: aRerankTime.
	allocatedBytes add: aByteCount.
	aBoolean ifTrue: [ failures := failures + 1 ]
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> allocatedBytes [

	^ allocatedBytes
]

{ #category : 'converting' }
CooNeuralBenchmarkResult >> asDictionary [

	| dictionary |
	dictionary := Dictionary new.
	dictionary
		at: #kind put: kind;
		at: #configuration put: configuration name;
		at: #key put: configuration key;
		at: #requests put: self size;
		at: #failures put: failures;
		at: #mrr put: self mrr;
		at: #recall1 put: (self recallAt: 1);
		at: #recall3 put: (self recallAt: 3);
		at: #recall5 put: (self recallAt: 5);
		at: #recall10 put: (self recallAt: 10);
		at: #mrrPerPrefix put: (self prefixSizesSeen collect: [ :size | size -> (self mrrForPrefixSize: size) ]) asArray;
		at: #meanMicroseconds put: (self mean: microseconds);
		at: #medianMicroseconds put: (self percentile: 0.5 of: microseconds);
		at: #p95Microseconds put: (self percentile: 0.95 of: microseconds);
		at: #p99Microseconds put: (self percentile: 0.99 of: microseconds);
		at: #meanRerankMicroseconds put: (self mean: rerankMicroseconds);
		at: #p95RerankMicroseconds put: (self percentile: 0.95 of: rerankMicroseconds);
		at: #meanAllocatedBytes put: (self mean: allocatedBytes);
		at: #medianAllocatedBytes put: (self percentile: 0.5 of: allocatedBytes);
		at: #p95AllocatedBytes put: (self percentile: 0.95 of: allocatedBytes);
		at: #packages put: packageNames asArray.
	configuration isReranked ifTrue: [
		dictionary
			at: #poolRecall put: self poolRecall;
			at: #meanIndexMilliseconds put: (self mean: indexMicroseconds) / 1000.0;
			at: #meanIndexBytes put: (self mean: indexBytes);
			at: #modelBytes put: modelBytes;
			at: #statisticsBytes put: statisticsBytes;
			at: #modelParameters put: modelParameters ].
	^ dictionary
]

{ #category : 'comparing' }
CooNeuralBenchmarkResult >> comparisonWith: aBaseResult [
	"Request by request: how many requests I rank better (wins), the same (ties) or worse (losses) than aBaseResult.
	A token absent from the first ten proposals has rank 11."

	| wins ties losses |
	self size = aBaseResult size ifFalse: [ self error: 'The two results are not over the same requests' ].
	wins := ties := losses := 0.
	ranks with: aBaseResult ranks do: [ :mine :theirs |
		| a b |
		a := mine = 0
			     ifTrue: [ 11 ]
			     ifFalse: [ mine ].
		b := theirs = 0
			     ifTrue: [ 11 ]
			     ifFalse: [ theirs ].
		a < b ifTrue: [ wins := wins + 1 ].
		a = b ifTrue: [ ties := ties + 1 ].
		a > b ifTrue: [ losses := losses + 1 ] ].
	^ Dictionary new
		  at: #wins put: wins;
		  at: #ties put: ties;
		  at: #losses put: losses;
		  at: #deltaMrr put: self mrr - aBaseResult mrr;
		  at: #deltaMeanMicroseconds put: (self mean: microseconds) - (aBaseResult mean: aBaseResult microseconds);
		  at: #deltaMeanAllocatedBytes
		  put: (self mean: allocatedBytes) - (aBaseResult mean: aBaseResult allocatedBytes);
		  yourself
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> configuration [

	^ configuration
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> failures [

	^ failures
]

{ #category : 'initialization' }
CooNeuralBenchmarkResult >> initialize [

	super initialize.
	ranks := OrderedCollection new.
	poolRanks := OrderedCollection new.
	prefixSizes := OrderedCollection new.
	microseconds := OrderedCollection new.
	rerankMicroseconds := OrderedCollection new.
	allocatedBytes := OrderedCollection new.
	indexMicroseconds := OrderedCollection new.
	indexBytes := OrderedCollection new.
	packageNames := OrderedCollection new.
	requestPackages := OrderedCollection new.
	failures := 0
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> kind [

	^ kind
]

{ #category : 'statistics' }
CooNeuralBenchmarkResult >> mean: aCollection [

	aCollection isEmpty ifTrue: [ ^ 0.0 ].
	^ (aCollection inject: 0 into: [ :sum :each | sum + each ]) / aCollection size asFloat
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> microseconds [

	^ microseconds
]

{ #category : 'recording' }
CooNeuralBenchmarkResult >> modelBytes: aModelByteCount statisticsBytes: aStatisticsByteCount parameters: aNumberOfParameters [

	modelBytes := aModelByteCount.
	statisticsBytes := aStatisticsByteCount.
	modelParameters := aNumberOfParameters
]

{ #category : 'metrics' }
CooNeuralBenchmarkResult >> mrr [
	"Mean reciprocal rank over the first ten proposals (MRR@10)."

	ranks isEmpty ifTrue: [ ^ 0.0 ].
	^ (ranks inject: 0.0 into: [ :sum :rank |
		   sum + (rank = 0
			    ifTrue: [ 0.0 ]
			    ifFalse: [ 1.0 / rank ]) ]) / ranks size
]

{ #category : 'metrics' }
CooNeuralBenchmarkResult >> mrrForPrefixSize: aSize [

	| sum count |
	sum := 0.0.
	count := 0.
	ranks with: prefixSizes do: [ :rank :size |
		size = aSize ifTrue: [
			count := count + 1.
			rank > 0 ifTrue: [ sum := sum + (1.0 / rank) ] ] ].
	count = 0 ifTrue: [ ^ 0.0 ].
	^ sum / count
]

{ #category : 'metrics' }
CooNeuralBenchmarkResult >> measuresForPackage: aPackageName [
	"Requests, MRR@10 and mean time of the requests of one package."

	| count sum time |
	count := 0.
	sum := 0.0.
	time := 0.
	1 to: ranks size do: [ :index |
		(requestPackages at: index) = aPackageName ifTrue: [
			| rank |
			rank := ranks at: index.
			count := count + 1.
			rank > 0 ifTrue: [ sum := sum + (1.0 / rank) ].
			time := time + (microseconds at: index) ] ].
	^ Dictionary new
		  at: #requests put: count;
		  at: #mrr put: (count = 0
				   ifTrue: [ 0.0 ]
				   ifFalse: [ sum / count ]);
		  at: #meanMicroseconds put: (count = 0
				   ifTrue: [ 0.0 ]
				   ifFalse: [ time / count asFloat ]);
		  yourself
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> packageNames [

	^ packageNames
]

{ #category : 'statistics' }
CooNeuralBenchmarkResult >> percentile: aFraction of: aCollection [

	| sorted index |
	aCollection isEmpty ifTrue: [ ^ 0 ].
	sorted := aCollection asArray sort.
	index := (aFraction * sorted size) ceiling max: 1.
	^ sorted at: (index min: sorted size)
]

{ #category : 'metrics' }
CooNeuralBenchmarkResult >> poolRecall [
	"How often the expected token was in the pool given to the re-ranker: the best the re-ranker can do."

	| known |
	known := poolRanks reject: [ :rank | rank < 0 ].
	known isEmpty ifTrue: [ ^ 0.0 ].
	^ (known count: [ :rank | rank > 0 ]) / known size asFloat
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> poolRanks [

	^ poolRanks
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> poolRanksLast [

	^ poolRanks last
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> prefixSizes [

	^ prefixSizes
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> prefixSizesSeen [

	^ prefixSizes asSet asArray sort
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> ranks [

	^ ranks
]

{ #category : 'metrics' }
CooNeuralBenchmarkResult >> recallAt: k [

	ranks isEmpty ifTrue: [ ^ 0.0 ].
	^ (ranks count: [ :rank | rank between: 1 and: k ]) / ranks size asFloat
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> rerankMicroseconds [

	^ rerankMicroseconds
]

{ #category : 'initialization' }
CooNeuralBenchmarkResult >> setKind: aKind configuration: aConfiguration [

	kind := aKind.
	configuration := aConfiguration
]

{ #category : 'accessing' }
CooNeuralBenchmarkResult >> size [

	^ ranks size
]
