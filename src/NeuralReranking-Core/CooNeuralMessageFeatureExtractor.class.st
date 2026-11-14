"
I compute the features of message (selector) completion candidates.

Dense features (see #featureNames): the rank of the candidate in the list of the heuristics, the prefix
and the remaining size, the arity, how often the selector is sent in the training corpus, how often it is
sent to this kind of receiver in the corpus (receiver keys: 'self', 'var:aStream', 'global:OrderedCollection',
'message:new', 'literal:ByteString', ...), how often it is sent in the rest of the package, whether the
package implements it, whether the class of the method understands it, and the kind of receiver.

Sub-words hashed for the embeddings: the candidate ('t:' sub-words and 'T:' the whole selector) and
the context ('r:' receiver, 'k:' kind of receiver, 'c:' class, 'm:' method selector).
"
Class {
	#name : 'CooNeuralMessageFeatureExtractor',
	#superclass : 'CooNeuralFeatureExtractor',
	#category : 'NeuralReranking-Core-Features',
	#package : 'NeuralReranking-Core',
	#tag : 'Features'
}

{ #category : 'receivers' }
CooNeuralMessageFeatureExtractor class >> pairKeyOf: aReceiverKey selector: aSelector [

	^ aReceiverKey , ' ' , aSelector
]

{ #category : 'receivers' }
CooNeuralMessageFeatureExtractor class >> receiverKeyOf: aMessageNode [

	| receiver kind |
	receiver := aMessageNode receiver.
	kind := self receiverKindOf: aMessageNode.
	kind = #self ifTrue: [ ^ 'self' ].
	kind = #super ifTrue: [ ^ 'super' ].
	kind = #literal ifTrue: [ ^ 'literal:' , receiver value class name ].
	kind = #message ifTrue: [ ^ 'message:' , receiver selector asString ].
	(#( #local #instance #global ) includes: kind) ifTrue: [ ^ kind asString , ':' , receiver name asString ].
	^ 'other:' , receiver class name
]

{ #category : 'receivers' }
CooNeuralMessageFeatureExtractor class >> receiverKindOf: aMessageNode [

	| receiver |
	receiver := aMessageNode receiver.
	receiver ifNil: [ ^ #other ].
	receiver isSelfVariable ifTrue: [ ^ #self ].
	receiver isSuperVariable ifTrue: [ ^ #super ].
	receiver isLiteralNode ifTrue: [ ^ #literal ].
	receiver isMessage ifTrue: [ ^ #message ].
	receiver isVariable ifTrue: [
		receiver isThisContextVariable ifTrue: [ ^ #other ].
		receiver isInstanceVariable ifTrue: [ ^ #instance ].
		(receiver name notEmpty and: [ receiver name first isUppercase ]) ifTrue: [ ^ #global ].
		^ #local ].
	^ #other
]

{ #category : 'receivers' }
CooNeuralMessageFeatureExtractor class >> receiverKinds [

	^ #( #self #super #literal #local #instance #global #message #other )
]

{ #category : 'features' }
CooNeuralMessageFeatureExtractor >> candidateFor: anEntry rank: aRank among: aSize prefix: aPrefix context: aContext [

	| token dense corpus pairKey pair total package index methodKey loo |
	token := anEntry contents asSymbol.
	index := aContext packageIndex.
	methodKey := aContext methodKey.
	loo := aContext leaveOneOut.
	dense := Array new: 24 withAll: 0.0.
	self fillRankFeaturesOf: aRank among: aSize prefix: aPrefix token: token into: dense.
	token numArgs = 0 ifTrue: [ dense at: 6 put: 1.0 ].
	(token numArgs = 1 and: [ token last ~= $: ]) ifTrue: [ dense at: 7 put: 1.0 ].
	(token notEmpty and: [ token last = $: ]) ifTrue: [ dense at: 8 put: 1.0 ].
	dense at: 9 put: ((token numArgs max: 0) min: 4) / 4.0.

	corpus := statistics selectorCount: token.
	loo ifTrue: [ corpus := corpus - ((index methodSendsAt: methodKey) occurrencesOf: token) max: 0 ].
	dense at: 10 put: (1 + corpus) ln / 12.0.

	pairKey := self class pairKeyOf: aContext receiverKey selector: token.
	pair := statistics pairCount: pairKey.
	total := statistics receiverCount: aContext receiverKey.
	loo ifTrue: [
		pair := pair - ((index methodPairsAt: methodKey) occurrencesOf: pairKey) max: 0.
		total := total - ((index methodReceiversAt: methodKey) occurrencesOf: aContext receiverKey) max: 0 ].
	dense at: 11 put: (1 + pair) ln / 8.0.
	dense at: 12 put: (total > 0
			 ifTrue: [ (pair min: total) / total asFloat ]
			 ifFalse: [ 0.0 ]).

	package := index sendCountOf: token excludingMethod: methodKey.
	dense at: 13 put: (1 + package) ln / 8.0.
	package > 0 ifTrue: [ dense at: 14 put: 1.0 ].
	(index implements: token) ifTrue: [ dense at: 15 put: 1.0 ].
	(aContext completionClass notNil and: [ aContext completionClass canUnderstand: token ]) ifTrue: [
		dense at: 16 put: 1.0 ].
	dense at: 16 + (self class receiverKinds indexOf: aContext receiverKind ifAbsent: [ 8 ]) put: 1.0.

	^ CooNeuralCandidate
		  token: token
		  dense: dense
		  fetcher: (anEntry fetcherName ifNil: [ #none ])
		  ids: (self idsOf: (CooNeuralText subwordsOf: token) tag: 't:') , { (self idOf: 'T:' , token) }
]

{ #category : 'features' }
CooNeuralMessageFeatureExtractor >> contextFor: aNode completionClass: aClass [

	| selector index receiverKey receiverKind ids |
	selector := aNode methodNode selector.
	index := (self indexForPackage: (self packageOfClass: aClass selector: selector)) ifNil: [ CooNeuralPackageIndex new ].
	receiverKey := self class receiverKeyOf: aNode.
	receiverKind := self class receiverKindOf: aNode.
	ids := (self idsOf: (CooNeuralText subwordsOf: (receiverKey copyAfter: $:)) tag: 'r:')
	       , { (self idOf: 'k:' , receiverKind) }
	       , (self idsOf: (CooNeuralText subwordsOf: (aClass ifNotNil: [ :class | class instanceSide name ])) tag: 'c:')
	       , (self idsOf: (CooNeuralText subwordsOf: selector) tag: 'm:').
	^ CooNeuralContext new
		  packageIndex: index;
		  methodKey: (CooNeuralPackageIndex keyOfClass: aClass selector: selector);
		  completionClass: aClass;
		  receiverKey: receiverKey;
		  receiverKind: receiverKind;
		  leaveOneOut: (self usesLeaveOneOutFor: index);
		  ids: ids;
		  yourself
]

{ #category : 'accessing' }
CooNeuralMessageFeatureExtractor >> featureNames [

	^ #( 'rank-inverse' 'rank-relative' 'rank-log' 'prefix-size' 'remaining-size'
	     'unary' 'binary' 'keyword' 'arguments'
	     'corpus-frequency' 'corpus-receiver-frequency' 'corpus-receiver-probability'
	     'package-frequency' 'package-used' 'package-implemented' 'class-understands'
	     'receiver-self' 'receiver-super' 'receiver-literal' 'receiver-local'
	     'receiver-instance' 'receiver-global' 'receiver-message' 'receiver-other' )
]

{ #category : 'accessing' }
CooNeuralMessageFeatureExtractor >> kind [

	^ #message
]
