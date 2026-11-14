"
I am one of the six compared configurations: a heuristic configuration of CooNeuralHeuristics
(#baseline, #semantics or #dependency), alone or re-ranked by the network trained on it.

    CooNeuralBenchmarkConfiguration all.
    (CooNeuralBenchmarkConfiguration base: #semantics reranked: true) builderFor: #message reranker: aReranker.
"
Class {
	#name : 'CooNeuralBenchmarkConfiguration',
	#superclass : 'Object',
	#instVars : [
		'base',
		'reranked'
	],
	#category : 'NeuralReranking-Benchmarks-Core',
	#package : 'NeuralReranking-Benchmarks',
	#tag : 'Core'
}

{ #category : 'instance creation' }
CooNeuralBenchmarkConfiguration class >> all [

	^ self allFor: CooNeuralHeuristics configurationNames
]

{ #category : 'instance creation' }
CooNeuralBenchmarkConfiguration class >> allFor: someBaseNames [

	| all |
	all := OrderedCollection new.
	someBaseNames do: [ :each |
		all
			add: (self base: each reranked: false);
			add: (self base: each reranked: true) ].
	^ all asArray
]

{ #category : 'instance creation' }
CooNeuralBenchmarkConfiguration class >> base: aBaseName reranked: aBoolean [

	^ self new
		  setBase: aBaseName asSymbol reranked: aBoolean;
		  yourself
]

{ #category : 'accessing' }
CooNeuralBenchmarkConfiguration >> base [

	^ base
]

{ #category : 'accessing' }
CooNeuralBenchmarkConfiguration >> baseConfiguration [
	"The configuration without re-ranking I am compared with."

	^ self class base: base reranked: false
]

{ #category : 'building' }
CooNeuralBenchmarkConfiguration >> builderFor: aKind reranker: aRerankerOrNil [

	| builder |
	builder := CooNeuralHeuristics builderFor: base kind: aKind.
	reranked ifFalse: [ ^ builder ].
	aRerankerOrNil ifNil: [ ^ self error: 'No re-ranker for ' , self name ].
	^ CooNeuralRerankingResultSetBuilder on: builder reranker: aRerankerOrNil
]

{ #category : 'comparing' }
CooNeuralBenchmarkConfiguration >> = anObject [

	^ self class = anObject class and: [ base = anObject base and: [ reranked = anObject isReranked ] ]
]

{ #category : 'comparing' }
CooNeuralBenchmarkConfiguration >> hash [

	^ base hash bitXor: reranked hash
]

{ #category : 'testing' }
CooNeuralBenchmarkConfiguration >> isReranked [

	^ reranked
]

{ #category : 'accessing' }
CooNeuralBenchmarkConfiguration >> key [
	"For file names and CSV: baseline, baseline-nr, ..."

	^ reranked
		  ifTrue: [ base , '-nr' ]
		  ifFalse: [ base asString ]
]

{ #category : 'accessing' }
CooNeuralBenchmarkConfiguration >> name [

	^ (CooNeuralHeuristics labelOf: base) , (reranked
		   ifTrue: [ ' + Re-ranking' ]
		   ifFalse: [ '' ])
]

{ #category : 'printing' }
CooNeuralBenchmarkConfiguration >> printOn: aStream [

	aStream nextPutAll: self name
]

{ #category : 'initialization' }
CooNeuralBenchmarkConfiguration >> setBase: aBaseName reranked: aBoolean [

	base := aBaseName.
	reranked := aBoolean
]
