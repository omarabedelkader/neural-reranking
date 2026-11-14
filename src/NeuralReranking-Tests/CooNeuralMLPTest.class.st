Class {
	#name : 'CooNeuralMLPTest',
	#superclass : 'TestCase',
	#category : 'NeuralReranking-Tests',
	#package : 'NeuralReranking-Tests'
}

{ #category : 'helpers' }
CooNeuralMLPTest >> model [

	^ CooNeuralMLP
		  denseSize: 3
		  fetcherNames: #( 'A' 'B' )
		  hiddenSize: 5
		  embeddingSize: 4
		  buckets: 11
		  seed: 7
]

{ #category : 'helpers' }
CooNeuralMLPTest >> queryWithRandom: aRandom target: aTargetIndex [

	^ CooNeuralQuery new
		  contextIds: #( 1 2 );
		  candidates: ((1 to: 4) collect: [ :index |
				   CooNeuralCandidate
					   token: ('c' , index printString) asSymbol
					   dense: ((1 to: 3) collect: [ :each | aRandom next * 2 - 1 ])
					   fetcher: (#( 'A' 'B' 'C' 'A' ) at: index)
					   ids: {
							   (index + 2).
							   9 } ]);
		  targetIndex: aTargetIndex;
		  yourself
]

{ #category : 'tests' }
CooNeuralMLPTest >> testDictionaryRoundTripKeepsTheScores [

	| model query copy |
	model := self model.
	query := self queryWithRandom: (Random seed: 1) target: 2.
	copy := CooNeuralMLP fromDictionary: (STON fromString: (STON toString: model asDictionary)).
	self assert: (copy scoresOf: query) equals: (model scoresOf: query).
	self assert: copy numberOfParameters equals: model numberOfParameters
]

{ #category : 'tests' }
CooNeuralMLPTest >> testGradientsMatchFiniteDifferences [
	"The hand-written backward pass against central finite differences of the loss."

	| model query epsilon numeric check |
	model := self model.
	query := self queryWithRandom: (Random seed: 3) target: 3.
	model accumulateGradientsOf: query.
	epsilon := 1.0e-6.
	numeric := [ :array :index |
	           | saved plus minus |
	           saved := array at: index.
	           array at: index put: saved + epsilon.
	           plus := model lossOf: query.
	           array at: index put: saved - epsilon.
	           minus := model lossOf: query.
	           array at: index put: saved.
	           plus - minus / (2 * epsilon) ].
	check := [ :analytic :array :index |
	         | expected |
	         expected := numeric value: array value: index.
	         self assert: (analytic - expected) abs < (1.0e-5 max: expected abs * 1.0e-4) ].
	1 to: 5 do: [ :row |
		#( 1 3 4 6 8 12 ) do: [ :column |
			check
				value: (model gradientOfW1At: row at: column)
				value: ((model instVarNamed: #w1) at: row)
				value: column ] ].
	1 to: 5 do: [ :index | check value: (model gradientOfW2At: index) value: (model instVarNamed: #w2) value: index ].
	check value: model gradientOfB2 value: (model instVarNamed: #b2) value: 1.
	#( 1 2 3 9 ) do: [ :id |
		1 to: 4 do: [ :index |
			check value: (model gradientOfEmbedding: id at: index) value: (model embeddings at: id) value: index ] ]
]

{ #category : 'tests' }
CooNeuralMLPTest >> testInputSize [

	| model |
	model := self model.
	"3 dense + 2 fetchers + 1 unknown fetcher + 2 x 4 embeddings"
	self assert: model inputSize equals: 14.
	self assert: model numberOfParameters equals: 5 * 14 + 5 + 5 + 1 + (11 * 4)
]

{ #category : 'tests' }
CooNeuralMLPTest >> testLearnsToRankByAFeature [
	"The expected candidate is the one with the largest first feature: the network must learn it."

	| random model queries before after |
	random := Random seed: 5.
	model := self model.
	queries := (1 to: 200) collect: [ :each |
		           | query |
		           query := self queryWithRandom: random target: 1.
		           query targetIndex: ((1 to: 4) detectMax: [ :index | (query candidates at: index) dense first ]).
		           query ].
	model normalizeWith: queries.
	before := queries inject: 0.0 into: [ :sum :query | sum + (model lossOf: query) ].
	5 timesRepeat: [
		queries do: [ :query |
			model accumulateGradientsOf: query.
			model applyGradientsWithLearningRate: 0.01 batchSize: 1 ] ].
	after := queries inject: 0.0 into: [ :sum :query | sum + (model lossOf: query) ].
	self assert: after < (before / 3)
]
