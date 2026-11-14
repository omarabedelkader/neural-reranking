"
I describe one kind of completion (#message or #variable) the way the static benchmarks of
HeuristicCompletion-Benchmarks do: which nodes of a method are call sites, what the expected token is,
how to replace it by a prefix and back, and which completion context to give to the builder.

The dataset extraction and the benchmarks use me, so the model is trained and tested on the same kind of
completion requests. The call sites of a package are always enumerated in the same order (methods sorted by
name), and #sample:max:seed:salt: samples them reproducibly.
"
Class {
	#name : 'CooNeuralTask',
	#superclass : 'Object',
	#category : 'NeuralReranking-Core-Tasks',
	#package : 'NeuralReranking-Core',
	#tag : 'Tasks'
}

{ #category : 'instance creation' }
CooNeuralTask class >> forKind: aKind [

	aKind asSymbol = #message ifTrue: [ ^ CooNeuralMessageTask new ].
	aKind asSymbol = #variable ifTrue: [ ^ CooNeuralVariableTask new ].
	^ self error: 'Unknown completion kind: ' , aKind printString
]

{ #category : 'accessing' }
CooNeuralTask class >> kinds [

	^ #( #message #variable )
]

{ #category : 'call sites' }
CooNeuralTask >> callsitesIn: aPackage [

	| methods callsites |
	methods := OrderedCollection new.
	(CoBenchmarkPackage on: aPackage) methodsDo: [ :method | methods add: method ].
	methods := methods asArray sort: [ :a :b | a printString <= b printString ].
	callsites := OrderedCollection new.
	methods do: [ :method |
		([ method parseTree ]
			 on: Error
			 do: [ nil ]) ifNotNil: [ :tree |
			tree nodesDo: [ :node | (self isCallsite: node) ifTrue: [ callsites add: node ] ] ] ].
	^ callsites
]

{ #category : 'completion' }
CooNeuralTask >> candidatesFrom: aBuilder for: aNode position: aPosition prefix: aPrefix size: aNumberOfCandidates [
	"The first candidates of aBuilder when the token of aNode is replaced by aPrefix (as the benchmarks do).
	aPosition must be computed before the token is replaced (see #positionOf:)."

	| completion |
	completion := aBuilder
		              node: aNode;
		              completionContext: (self contextFor: aNode position: aPosition);
		              buildCompletion.
	completion replaceFilterWith: (CoCaseSensitiveBeginsWithFilter filterString: aPrefix).
	^ (completion first: aNumberOfCandidates) asArray
]

{ #category : 'completion' }
CooNeuralTask >> completionClassOf: aNode [

	^ aNode methodNode methodClass
]

{ #category : 'completion' }
CooNeuralTask >> contextFor: aNode position: aPosition [

	^ self subclassResponsibility
]

{ #category : 'testing' }
CooNeuralTask >> isCallsite: aNode [

	^ self subclassResponsibility
]

{ #category : 'accessing' }
CooNeuralTask >> kind [

	^ self subclassResponsibility
]

{ #category : 'call sites' }
CooNeuralTask >> maxPrefixSizeFor: aToken [

	^ aToken size min: 8
]

{ #category : 'accessing' }
CooNeuralTask >> newFeatureExtractor [

	^ CooNeuralFeatureExtractor forKind: self kind
]

{ #category : 'completion' }
CooNeuralTask >> positionOf: aNode [
	"The position of the completion, computed on the original node (before its token is replaced by a prefix)."

	^ self subclassResponsibility
]

{ #category : 'call sites' }
CooNeuralTask >> rankOf: aToken in: aCollectionOfEntries [
	"1-based index of aToken among the entries, 0 when absent."

	| token |
	token := aToken asString.
	aCollectionOfEntries doWithIndex: [ :entry :index | entry contents asString = token ifTrue: [ ^ index ] ].
	^ 0
]

{ #category : 'call sites' }
CooNeuralTask >> restore: aToken on: aNode [

	self subclassResponsibility
]

{ #category : 'call sites' }
CooNeuralTask >> sample: aCollectionOfCallsites max: aMaximumOrNil seed: aSeed salt: aString [
	"At most aMaximumOrNil call sites (all of them when nil or not positive), in their original order."

	| indexes |
	(aMaximumOrNil isNil or: [ aMaximumOrNil <= 0 or: [ aCollectionOfCallsites size <= aMaximumOrNil ] ])
		ifTrue: [ ^ aCollectionOfCallsites asArray ].
	indexes := (1 to: aCollectionOfCallsites size) asArray shuffleBy:
		           (Random seed: (aSeed + (CooNeuralText fnv1a: aString)) \\ 16r7FFFFFFF).
	^ ((indexes first: aMaximumOrNil) sort collect: [ :index | aCollectionOfCallsites at: index ]) asArray
]

{ #category : 'call sites' }
CooNeuralTask >> setPrefix: aPrefix on: aNode [

	self subclassResponsibility
]

{ #category : 'call sites' }
CooNeuralTask >> targetOf: aNode [

	^ self subclassResponsibility
]
