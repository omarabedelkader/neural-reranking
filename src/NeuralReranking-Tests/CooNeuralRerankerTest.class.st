Class {
	#name : 'CooNeuralRerankerTest',
	#superclass : 'TestCase',
	#category : 'NeuralReranking-Tests',
	#package : 'NeuralReranking-Tests'
}

{ #category : 'helpers' }
CooNeuralRerankerTest >> rerankerForKind: aKind [
	"An untrained re-ranker: enough to check the plumbing."

	| extractor model |
	extractor := (CooNeuralFeatureExtractor forKind: aKind)
		             buckets: 64;
		             yourself.
	model := CooNeuralMLP
		         denseSize: extractor denseSize
		         fetcherNames: #( 'CoGlobalSelectorFetcher' )
		         hiddenSize: 4
		         embeddingSize: 3
		         buckets: 64
		         seed: 1.
	^ (CooNeuralReranker model: model extractor: extractor)
		  poolSize: 15;
		  configurationName: #baseline;
		  yourself
]

{ #category : 'tests' }
CooNeuralRerankerTest >> testBenchmarkRunnerComparesConfigurationsOnTheSameRequests [

	| runner results comparison |
	runner := CooNeuralBenchmarkRunner new
		          kind: #message;
		          configurations: (CooNeuralBenchmarkConfiguration allFor: #( #baseline ));
		          rerankers: (Dictionary new
				           at: #baseline put: (self rerankerForKind: #message);
				           yourself);
		          yourself.
	runner run: { CooNeuralFixture package }.
	results := runner results.
	self assert: results size equals: 2.
	self assert: results first size > 0.
	self assert: results first size equals: results second size.
	self assert: results first prefixSizes asArray equals: results second prefixSizes asArray.
	self assert: (results second poolRanks allSatisfy: [ :rank | rank >= 0 ]).
	self assert: (results first poolRanks allSatisfy: [ :rank | rank = -1 ]).
	comparison := results second comparisonWith: results first.
	self
		assert: (comparison at: #wins) + (comparison at: #ties) + (comparison at: #losses)
		equals: results first size.
	self assert: (runner benchmarks first textReport includesSubstring: 'MMR')
]

{ #category : 'tests' }
CooNeuralRerankerTest >> testConfigurations [

	| all |
	all := CooNeuralBenchmarkConfiguration all.
	self assert: all size equals: 6.
	self assert: (all collect: [ :each | each key ]) asArray
		equals: #( 'baseline' 'baseline-nr' 'semantics' 'semantics-nr' 'dependency' 'dependency-nr' ).
	self assert: (all select: [ :each | each isReranked ]) size equals: 3.
	self assert: (all second baseConfiguration) equals: all first
]

{ #category : 'tests' }
CooNeuralRerankerTest >> testDecoratedBuilderAnswersAPermutationOfThePool [

	| task node position builder plain reranked |
	task := CooNeuralTask forKind: #message.
	node := (task callsitesIn: CooNeuralFixture package) detect: [ :each | each selector = #cooNeuralSharedSelector ].
	position := task positionOf: node.
	task setPrefix: 'co' on: node.
	[
	plain := task
		         candidatesFrom: (CooNeuralHeuristics builderFor: #baseline kind: #message)
		         for: node
		         position: position
		         prefix: 'co'
		         size: 15.
	builder := CooNeuralRerankingResultSetBuilder
		           on: (CooNeuralHeuristics builderFor: #baseline kind: #message)
		           reranker: (self rerankerForKind: #message).
	reranked := task
		            candidatesFrom: builder
		            for: node
		            position: position
		            prefix: 'co'
		            size: 15 ] ensure: [ task restore: #cooNeuralSharedSelector on: node ].
	self assert: reranked size equals: plain size.
	self
		assert: (reranked collect: [ :each | each contents ]) asSet
		equals: (plain collect: [ :each | each contents ]) asSet
]

{ #category : 'tests' }
CooNeuralRerankerTest >> testFootprint [

	self assert: (CooNeuralFootprint bytesOf: (Array new: 10)) equals: (Array new: 10) sizeInMemory.
	self
		assert: (CooNeuralFootprint bytesOf: { 'abcd'. #shared. 3 })
		equals: (Array new: 3) sizeInMemory + 'abcd' sizeInMemory
]

{ #category : 'tests' }
CooNeuralRerankerTest >> testSaveAndLoad [

	| reranker file loaded |
	reranker := self rerankerForKind: #variable.
	file := FileSystem memory / 'models' / 'variable-baseline.ston'.
	reranker saveTo: file.
	loaded := CooNeuralReranker loadFrom: file.
	self assert: loaded kind equals: #variable.
	self assert: loaded poolSize equals: 15.
	self assert: loaded model asDictionary equals: reranker model asDictionary
]
