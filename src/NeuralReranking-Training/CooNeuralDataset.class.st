"
I am the queries extracted from some packages for one kind of completion and one heuristic configuration
(see CooNeuralDatasetBuilder). I only keep the queries whose expected token is among the candidates of the
pool: the re-ranker cannot do anything for the others, but I count them (missing) so that the measures
are over all the completion requests.
"
Class {
	#name : 'CooNeuralDataset',
	#superclass : 'Object',
	#instVars : [
		'queries',
		'missing',
		'errors',
		'errorDescriptions',
		'packageNames',
		'extractionMicroseconds'
	],
	#category : 'NeuralReranking-Training',
	#package : 'NeuralReranking-Training'
}

{ #category : 'adding' }
CooNeuralDataset >> addError: anError [

	errors := errors + 1.
	errorDescriptions add: anError class name , ': ' , anError messageText asString
]

{ #category : 'accessing' }
CooNeuralDataset >> errorDescriptions [

	^ errorDescriptions
]

{ #category : 'adding' }
CooNeuralDataset >> addMissing [

	missing := missing + 1
]

{ #category : 'adding' }
CooNeuralDataset >> addPackageName: aString [

	packageNames add: aString
]

{ #category : 'adding' }
CooNeuralDataset >> addQuery: aQuery [

	queries add: aQuery
]

{ #category : 'accessing' }
CooNeuralDataset >> errors [

	^ errors
]

{ #category : 'accessing' }
CooNeuralDataset >> extractionMicroseconds [

	^ extractionMicroseconds ifNil: [ 0 ]
]

{ #category : 'accessing' }
CooNeuralDataset >> extractionMicroseconds: anInteger [

	extractionMicroseconds := anInteger
]

{ #category : 'accessing' }
CooNeuralDataset >> fetcherNames [

	| names |
	names := Set new.
	queries do: [ :query | query candidates do: [ :candidate | names add: candidate fetcher asString ] ].
	^ names asArray sort
]

{ #category : 'initialization' }
CooNeuralDataset >> initialize [

	super initialize.
	queries := OrderedCollection new.
	missing := 0.
	errors := 0.
	errorDescriptions := Bag new.
	packageNames := OrderedCollection new
]

{ #category : 'accessing' }
CooNeuralDataset >> missing [

	^ missing
]

{ #category : 'accessing' }
CooNeuralDataset >> packageNames [

	^ packageNames
]

{ #category : 'accessing' }
CooNeuralDataset >> queries [

	^ queries
]

{ #category : 'accessing' }
CooNeuralDataset >> size [

	^ queries size
]

{ #category : 'accessing' }
CooNeuralDataset >> total [
	"All the completion requests, with the ones whose expected token was not in the pool."

	^ queries size + missing
]
