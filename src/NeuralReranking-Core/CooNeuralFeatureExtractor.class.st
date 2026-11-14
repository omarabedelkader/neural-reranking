"
I turn the candidates of one completion request into a CooNeuralQuery, the input of the network.
My subclasses define the features of message completion and of variable (class name) completion.

I only use what a developer has when the completion is requested: the prefix, the candidates and their
order, the receiver, the class and the method being written, the rest of the package (the method itself
is excluded, see CooNeuralPackageIndex) and the statistics of the training packages.

The indexes of the packages are built once per package and cached (see #prepareForPackage:).
"
Class {
	#name : 'CooNeuralFeatureExtractor',
	#superclass : 'Object',
	#instVars : [
		'statistics',
		'buckets',
		'packageIndexes',
		'leaveOneOut'
	],
	#category : 'NeuralReranking-Core-Features',
	#package : 'NeuralReranking-Core',
	#tag : 'Features'
}

{ #category : 'instance creation' }
CooNeuralFeatureExtractor class >> forKind: aKind [

	aKind = #message ifTrue: [ ^ CooNeuralMessageFeatureExtractor new ].
	aKind = #variable ifTrue: [ ^ CooNeuralVariableFeatureExtractor new ].
	^ self error: 'Unknown completion kind: ' , aKind printString
]

{ #category : 'instance creation' }
CooNeuralFeatureExtractor class >> fromDictionary: aDictionary [

	^ (self forKind: (aDictionary at: #kind) asSymbol)
		  fromDictionary: aDictionary;
		  yourself
]

{ #category : 'converting' }
CooNeuralFeatureExtractor >> asDictionary [

	^ Dictionary new
		  at: #kind put: self kind;
		  at: #buckets put: buckets;
		  at: #featureNames put: self featureNames;
		  at: #statistics put: (statistics asDictionaryForKind: self kind);
		  yourself
]

{ #category : 'accessing' }
CooNeuralFeatureExtractor >> buckets [

	^ buckets
]

{ #category : 'accessing' }
CooNeuralFeatureExtractor >> buckets: anInteger [

	buckets := anInteger
]

{ #category : 'features' }
CooNeuralFeatureExtractor >> candidateFor: anEntry rank: aRank among: aSize prefix: aPrefix context: aContext [

	^ self subclassResponsibility
]

{ #category : 'features' }
CooNeuralFeatureExtractor >> contextFor: aNode completionClass: aClass [

	^ self subclassResponsibility
]

{ #category : 'accessing' }
CooNeuralFeatureExtractor >> denseSize [

	^ self featureNames size
]

{ #category : 'accessing' }
CooNeuralFeatureExtractor >> featureNames [

	^ self subclassResponsibility
]

{ #category : 'features' }
CooNeuralFeatureExtractor >> fillRankFeaturesOf: aRank among: aSize prefix: aPrefix token: aToken into: anArray [
	"The five first features, shared by all the kinds of completion."

	anArray
		at: 1 put: 1.0 / aRank;
		at: 2 put: (aSize > 1
				 ifTrue: [ aRank - 1 / (aSize - 1) asFloat ]
				 ifFalse: [ 0.0 ]);
		at: 3 put: aRank asFloat ln / 51 ln;
		at: 4 put: aPrefix size / 8.0;
		at: 5 put: ((aToken size - aPrefix size max: 0) min: 20) / 20.0
]

{ #category : 'caching' }
CooNeuralFeatureExtractor >> forgetPackage: aPackage [

	packageIndexes removeKey: aPackage name asString ifAbsent: [  ]
]

{ #category : 'converting' }
CooNeuralFeatureExtractor >> fromDictionary: aDictionary [

	buckets := aDictionary at: #buckets.
	statistics := CooNeuralCorpusStatistics fromDictionary: (aDictionary at: #statistics).
	(aDictionary at: #featureNames ifAbsent: [ self featureNames ]) asArray = self featureNames asArray
		ifFalse: [ self error: 'The model was trained with other features' ]
]

{ #category : 'hashing' }
CooNeuralFeatureExtractor >> idOf: aString [

	^ CooNeuralText bucketOf: aString among: buckets
]

{ #category : 'hashing' }
CooNeuralFeatureExtractor >> idsOf: aCollectionOfWords tag: aTag [

	| words |
	words := aCollectionOfWords size > 8
		         ifTrue: [ aCollectionOfWords first: 8 ]
		         ifFalse: [ aCollectionOfWords ].
	^ words asArray collect: [ :word | self idOf: aTag , word ]
]

{ #category : 'caching' }
CooNeuralFeatureExtractor >> indexForPackage: aPackageOrNil [

	aPackageOrNil ifNil: [ ^ nil ].
	^ packageIndexes
		  at: aPackageOrNil name asString
		  ifAbsentPut: [ CooNeuralPackageIndex on: aPackageOrNil ]
]

{ #category : 'initialization' }
CooNeuralFeatureExtractor >> initialize [

	super initialize.
	buckets := 4096.
	packageIndexes := Dictionary new.
	leaveOneOut := false.
	statistics := CooNeuralCorpusStatistics new
]

{ #category : 'accessing' }
CooNeuralFeatureExtractor >> kind [

	^ self subclassResponsibility
]

{ #category : 'accessing' }
CooNeuralFeatureExtractor >> leaveOneOut [

	^ leaveOneOut
]

{ #category : 'accessing' }
CooNeuralFeatureExtractor >> leaveOneOut: aBoolean [
	"When true, the counts of the method being completed are removed from the corpus statistics
	(only for the methods of the packages the statistics were built from)."

	leaveOneOut := aBoolean
]

{ #category : 'features' }
CooNeuralFeatureExtractor >> methodKeyOf: aNode completionClass: aClass [

	^ CooNeuralPackageIndex keyOfClass: aClass selector: aNode methodNode selector
]

{ #category : 'caching' }
CooNeuralFeatureExtractor >> packageIndexes [

	^ packageIndexes
]

{ #category : 'features' }
CooNeuralFeatureExtractor >> packageOfClass: aClassOrNil selector: aSelector [
	"The package of the method being written: an extension method belongs to its own package."

	aClassOrNil ifNil: [ ^ nil ].
	^ (aClassOrNil includesSelector: aSelector)
		  ifTrue: [ (aClassOrNil >> aSelector) package ]
		  ifFalse: [ aClassOrNil package ]
]

{ #category : 'caching' }
CooNeuralFeatureExtractor >> prepareForPackage: aPackage [
	"Build the index of aPackage before the first completion in it; answer it."

	^ self indexForPackage: aPackage
]

{ #category : 'features' }
CooNeuralFeatureExtractor >> queryFor: aCollectionOfEntries prefix: aPrefix node: aNode completionClass: aClass [

	| context entries |
	context := self contextFor: aNode completionClass: aClass.
	entries := aCollectionOfEntries asArray.
	^ CooNeuralQuery new
		  prefixSize: aPrefix size;
		  contextIds: context ids;
		  candidates: (entries withIndexCollect: [ :entry :rank |
				   self
					   candidateFor: entry
					   rank: rank
					   among: entries size
					   prefix: aPrefix
					   context: context ]);
		  yourself
]

{ #category : 'caching' }
CooNeuralFeatureExtractor >> resetPackageIndexes [

	packageIndexes := Dictionary new
]

{ #category : 'accessing' }
CooNeuralFeatureExtractor >> statistics [

	^ statistics
]

{ #category : 'accessing' }
CooNeuralFeatureExtractor >> statistics: aCorpusStatistics [

	statistics := aCorpusStatistics
]

{ #category : 'features' }
CooNeuralFeatureExtractor >> usesLeaveOneOutFor: aPackageIndexOrNil [

	^ leaveOneOut and: [ aPackageIndexOrNil notNil and: [ statistics includesPackageNamed: aPackageIndexOrNil packageName ] ]
]
