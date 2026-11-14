"
I re-rank the first candidates proposed by a Complishon builder with a trained CooNeuralMLP.

The heuristics give the first poolSize candidates for the prefix (the pool); I compute their features
(CooNeuralFeatureExtractor), score them with the network and answer them by decreasing score
(ties keep the order of the heuristics).

I keep the time of my last re-ranking (lastMicroseconds) and the pool (lastPool), for the benchmarks.

I am saved and loaded as a STON file holding the network, the feature extractor (with the corpus
statistics) and a summary of the training:

    reranker saveTo: 'models/message-semantics.ston'.
    reranker := CooNeuralReranker loadFrom: 'models/message-semantics.ston'.

To use me on top of a builder, see CooNeuralRerankingResultSetBuilder.
"
Class {
	#name : 'CooNeuralReranker',
	#superclass : 'Object',
	#instVars : [
		'model',
		'extractor',
		'poolSize',
		'configurationName',
		'trainingSummary',
		'lastMicroseconds',
		'lastPool'
	],
	#category : 'NeuralReranking-Core-Model',
	#package : 'NeuralReranking-Core',
	#tag : 'Model'
}

{ #category : 'instance creation' }
CooNeuralReranker class >> fromDictionary: aDictionary [

	^ self new
		  fromDictionary: aDictionary;
		  yourself
]

{ #category : 'instance creation' }
CooNeuralReranker class >> loadFrom: aFileReferenceOrString [

	^ self fromDictionary: (aFileReferenceOrString asFileReference readStreamDo: [ :stream | STON fromStream: stream ])
]

{ #category : 'instance creation' }
CooNeuralReranker class >> model: aModel extractor: anExtractor [

	aModel buckets = anExtractor buckets ifFalse: [
		self error: 'The network and the feature extractor must use the same number of hash buckets' ].
	^ self new
		  model: aModel;
		  extractor: anExtractor;
		  yourself
]

{ #category : 'converting' }
CooNeuralReranker >> asDictionary [

	^ Dictionary new
		  at: #format put: 1;
		  at: #kind put: self kind;
		  at: #configuration put: configurationName;
		  at: #poolSize put: poolSize;
		  at: #model put: model asDictionary;
		  at: #extractor put: extractor asDictionary;
		  at: #training put: trainingSummary;
		  yourself
]

{ #category : 'accessing' }
CooNeuralReranker >> configurationName [

	^ configurationName
]

{ #category : 'accessing' }
CooNeuralReranker >> configurationName: aString [

	configurationName := aString
]

{ #category : 'accessing' }
CooNeuralReranker >> extractor [

	^ extractor
]

{ #category : 'accessing' }
CooNeuralReranker >> extractor: aFeatureExtractor [

	extractor := aFeatureExtractor
]

{ #category : 'caching' }
CooNeuralReranker >> forgetPackage: aPackage [

	extractor forgetPackage: aPackage
]

{ #category : 'converting' }
CooNeuralReranker >> fromDictionary: aDictionary [

	configurationName := aDictionary at: #configuration ifAbsent: [ nil ].
	poolSize := aDictionary at: #poolSize ifAbsent: [ 20 ].
	model := CooNeuralMLP fromDictionary: (aDictionary at: #model).
	model releaseOptimizer.
	extractor := CooNeuralFeatureExtractor fromDictionary: (aDictionary at: #extractor).
	trainingSummary := aDictionary at: #training ifAbsent: [ Dictionary new ]
]

{ #category : 'initialization' }
CooNeuralReranker >> initialize [

	super initialize.
	poolSize := 20.
	lastMicroseconds := 0.
	lastPool := #(  ).
	trainingSummary := Dictionary new
]

{ #category : 'accessing' }
CooNeuralReranker >> kind [

	^ extractor kind
]

{ #category : 'accessing' }
CooNeuralReranker >> lastMicroseconds [

	^ lastMicroseconds
]

{ #category : 'accessing' }
CooNeuralReranker >> lastPool [

	^ lastPool
]

{ #category : 'accessing' }
CooNeuralReranker >> model [

	^ model
]

{ #category : 'accessing' }
CooNeuralReranker >> model: aModel [

	model := aModel
]

{ #category : 'accessing' }
CooNeuralReranker >> poolSize [

	^ poolSize
]

{ #category : 'accessing' }
CooNeuralReranker >> poolSize: anInteger [

	poolSize := anInteger
]

{ #category : 'caching' }
CooNeuralReranker >> prepareForPackage: aPackage [

	^ extractor prepareForPackage: aPackage
]

{ #category : 'printing' }
CooNeuralReranker >> printOn: aStream [

	super printOn: aStream.
	aStream
		nextPut: $(;
		print: self kind;
		space;
		nextPutAll: configurationName asString;
		nextPutAll: ', pool ';
		print: poolSize;
		nextPut: $)
]

{ #category : 'reranking' }
CooNeuralReranker >> rerank: aCollectionOfEntries prefix: aPrefix node: aNode completionClass: aClass [

	| start entries query scores order |
	start := Time microsecondClockValue.
	entries := aCollectionOfEntries asArray.
	lastPool := entries.
	entries size < 2 ifTrue: [
		lastMicroseconds := Time microsecondClockValue - start.
		^ entries ].
	query := extractor queryFor: entries prefix: aPrefix node: aNode completionClass: aClass.
	scores := model scoresOf: query.
	order := (1 to: entries size) asArray sort: [ :a :b |
		         (scores at: a) > (scores at: b) or: [ (scores at: a) = (scores at: b) and: [ a < b ] ] ].
	order := order collect: [ :index | entries at: index ].
	lastMicroseconds := Time microsecondClockValue - start.
	^ order
]

{ #category : 'reranking' }
CooNeuralReranker >> resetLast [

	lastMicroseconds := 0.
	lastPool := #(  )
]

{ #category : 'saving' }
CooNeuralReranker >> saveTo: aFileReferenceOrString [

	| file |
	file := aFileReferenceOrString asFileReference.
	file parent ensureCreateDirectory.
	file ensureDelete.
	file writeStreamDo: [ :stream | STON put: self asDictionary onStream: stream ]
]

{ #category : 'accessing' }
CooNeuralReranker >> trainingSummary [

	^ trainingSummary
]

{ #category : 'accessing' }
CooNeuralReranker >> trainingSummary: aDictionary [

	trainingSummary := aDictionary
]
