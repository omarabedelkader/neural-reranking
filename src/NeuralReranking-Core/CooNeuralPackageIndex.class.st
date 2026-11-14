"
I index the code of one package for the features of the re-ranker: the selectors it sends, the globals
(capitalized variables) it references and the selectors it implements, in total and per method and class.

The per-method counts let the features ignore the method that contains the call site being completed:
in a static benchmark the method is already written, so without that the package would 'know' the
expected token. #sendCountOf:excludingMethod: and friends answer the counts of the rest of the package.

I am built once per package (see CooNeuralFeatureExtractor>>#indexForPackage:) and my building time
is kept in buildMicroseconds, so the benchmark reports it separately from the completion time.
"
Class {
	#name : 'CooNeuralPackageIndex',
	#superclass : 'Object',
	#instVars : [
		'packageName',
		'sends',
		'globals',
		'implementedSelectors',
		'methodSends',
		'methodPairs',
		'methodReceivers',
		'methodGlobals',
		'classGlobals',
		'buildMicroseconds'
	],
	#classVars : [
		'EmptyBag'
	],
	#category : 'NeuralReranking-Core-Features',
	#package : 'NeuralReranking-Core',
	#tag : 'Features'
}

{ #category : 'accessing' }
CooNeuralPackageIndex class >> emptyBag [

	^ EmptyBag ifNil: [ EmptyBag := Bag new ]
]

{ #category : 'accessing' }
CooNeuralPackageIndex class >> keyOfClass: aClassOrNil selector: aSelector [

	^ (aClassOrNil ifNil: [ 'nil' ] ifNotNil: [ :class | class name ]) , '>>' , aSelector asString
]

{ #category : 'instance creation' }
CooNeuralPackageIndex class >> on: aPackage [

	^ self new
		  buildOn: aPackage;
		  yourself
]

{ #category : 'building' }
CooNeuralPackageIndex >> addMethod: aCompiledMethod [

	| tree key mSends mPairs mReceivers mGlobals cGlobals |
	implementedSelectors add: aCompiledMethod selector.
	tree := [ aCompiledMethod parseTree ]
		        on: Error
		        do: [ nil ].
	tree ifNil: [ ^ self ].
	key := self class keyOfClass: aCompiledMethod methodClass selector: aCompiledMethod selector.
	mSends := Bag new.
	mPairs := Bag new.
	mReceivers := Bag new.
	mGlobals := Bag new.
	cGlobals := classGlobals at: aCompiledMethod methodClass name ifAbsentPut: [ Bag new ].
	tree nodesDo: [ :node |
		node isMessage ifTrue: [
			| receiverKey |
			receiverKey := CooNeuralMessageFeatureExtractor receiverKeyOf: node.
			sends add: node selector.
			mSends add: node selector.
			mReceivers add: receiverKey.
			mPairs add: (CooNeuralMessageFeatureExtractor pairKeyOf: receiverKey selector: node selector) ].
		(node isVariable and: [ node name notEmpty and: [ node name first isUppercase ] ]) ifTrue: [
			| name |
			name := node name asSymbol.
			globals add: name.
			mGlobals add: name.
			cGlobals add: name ] ].
	methodSends at: key put: mSends.
	methodPairs at: key put: mPairs.
	methodReceivers at: key put: mReceivers.
	methodGlobals at: key put: mGlobals
]

{ #category : 'building' }
CooNeuralPackageIndex >> buildOn: aPackage [

	| start |
	start := Time microsecondClockValue.
	packageName := aPackage name asString.
	aPackage methods do: [ :method | self addMethod: method ].
	buildMicroseconds := Time microsecondClockValue - start
]

{ #category : 'accessing' }
CooNeuralPackageIndex >> buildMicroseconds [

	^ buildMicroseconds ifNil: [ 0 ]
]

{ #category : 'counting' }
CooNeuralPackageIndex >> classGlobalCountOf: aName inClass: aClassOrNil excludingMethod: aMethodKey [

	| inClass |
	aClassOrNil ifNil: [ ^ 0 ].
	inClass := (classGlobals at: aClassOrNil name ifAbsent: [ self class emptyBag ]) occurrencesOf: aName.
	^ inClass - ((self methodGlobalsAt: aMethodKey) occurrencesOf: aName) max: 0
]

{ #category : 'counting' }
CooNeuralPackageIndex >> globalCountOf: aName excludingMethod: aMethodKey [

	^ (globals occurrencesOf: aName) - ((self methodGlobalsAt: aMethodKey) occurrencesOf: aName) max: 0
]

{ #category : 'accessing' }
CooNeuralPackageIndex >> globals [

	^ globals
]

{ #category : 'testing' }
CooNeuralPackageIndex >> implements: aSelector [

	^ implementedSelectors includes: aSelector
]

{ #category : 'initialization' }
CooNeuralPackageIndex >> initialize [

	super initialize.
	sends := Bag new.
	globals := Bag new.
	implementedSelectors := Set new.
	methodSends := Dictionary new.
	methodPairs := Dictionary new.
	methodReceivers := Dictionary new.
	methodGlobals := Dictionary new.
	classGlobals := Dictionary new
]

{ #category : 'accessing' }
CooNeuralPackageIndex >> methodGlobalsAt: aMethodKey [

	^ methodGlobals at: aMethodKey ifAbsent: [ self class emptyBag ]
]

{ #category : 'accessing' }
CooNeuralPackageIndex >> methodKeys [

	^ methodSends keys
]

{ #category : 'accessing' }
CooNeuralPackageIndex >> methodPairsAt: aMethodKey [

	^ methodPairs at: aMethodKey ifAbsent: [ self class emptyBag ]
]

{ #category : 'accessing' }
CooNeuralPackageIndex >> methodReceiversAt: aMethodKey [

	^ methodReceivers at: aMethodKey ifAbsent: [ self class emptyBag ]
]

{ #category : 'accessing' }
CooNeuralPackageIndex >> methodSendsAt: aMethodKey [

	^ methodSends at: aMethodKey ifAbsent: [ self class emptyBag ]
]

{ #category : 'accessing' }
CooNeuralPackageIndex >> packageName [

	^ packageName
]

{ #category : 'printing' }
CooNeuralPackageIndex >> printOn: aStream [

	super printOn: aStream.
	aStream
		nextPut: $(;
		nextPutAll: packageName asString;
		nextPut: $)
]

{ #category : 'counting' }
CooNeuralPackageIndex >> sendCountOf: aSelector excludingMethod: aMethodKey [

	^ (sends occurrencesOf: aSelector) - ((self methodSendsAt: aMethodKey) occurrencesOf: aSelector) max: 0
]

{ #category : 'accessing' }
CooNeuralPackageIndex >> sends [

	^ sends
]
