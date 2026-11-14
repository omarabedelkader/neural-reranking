"
I count, over the training packages only, how often every selector is sent, how often a selector is sent
to a kind of receiver (see CooNeuralMessageFeatureExtractor class>>#receiverKeyOf:) and how often every
global is referenced. These counts are features of the re-ranker, like a unigram/bigram language model.

The receiver/selector pairs seen only once are dropped to keep the model small.

When the dataset of the training packages is extracted, the feature extractor removes the counts of the
method being completed (leave-one-out, see CooNeuralFeatureExtractor>>#leaveOneOut:), otherwise the
training call sites would see themselves in these counts while the test call sites never do.
"
Class {
	#name : 'CooNeuralCorpusStatistics',
	#superclass : 'Object',
	#instVars : [
		'packageNames',
		'selectorCounts',
		'pairCounts',
		'receiverCounts',
		'globalCounts',
		'buildMicroseconds'
	],
	#category : 'NeuralReranking-Core-Features',
	#package : 'NeuralReranking-Core',
	#tag : 'Features'
}

{ #category : 'instance creation' }
CooNeuralCorpusStatistics class >> buildFrom: aCollectionOfPackages [

	^ self new
		  buildFrom: aCollectionOfPackages;
		  yourself
]

{ #category : 'instance creation' }
CooNeuralCorpusStatistics class >> fromDictionary: aDictionary [

	^ self new
		  fromDictionary: aDictionary;
		  yourself
]

{ #category : 'private' }
CooNeuralCorpusStatistics >> add: aCount to: aKey in: aDictionary [

	aDictionary at: aKey put: (aDictionary at: aKey ifAbsent: [ 0 ]) + aCount
]

{ #category : 'building' }
CooNeuralCorpusStatistics >> addIndex: aPackageIndex [

	packageNames add: aPackageIndex packageName.
	aPackageIndex sends doWithOccurrences: [ :selector :count | self add: count to: selector in: selectorCounts ].
	aPackageIndex globals doWithOccurrences: [ :name :count | self add: count to: name in: globalCounts ].
	aPackageIndex methodKeys do: [ :key |
		(aPackageIndex methodPairsAt: key) doWithOccurrences: [ :pair :count | self add: count to: pair in: pairCounts ].
		(aPackageIndex methodReceiversAt: key) doWithOccurrences: [ :receiver :count |
			self add: count to: receiver in: receiverCounts ] ]
]

{ #category : 'converting' }
CooNeuralCorpusStatistics >> asDictionaryForKind: aKind [
	"Only what the features of aKind (#message or #variable) need."

	| dictionary |
	dictionary := Dictionary new.
	dictionary at: #packageNames put: packageNames asArray sort.
	aKind = #message
		ifTrue: [
			dictionary
				at: #selectorCounts put: selectorCounts;
				at: #pairCounts put: pairCounts;
				at: #receiverCounts put: receiverCounts ]
		ifFalse: [ dictionary at: #globalCounts put: globalCounts ].
	^ dictionary
]

{ #category : 'building' }
CooNeuralCorpusStatistics >> buildFrom: aCollectionOfPackages [

	| start |
	start := Time microsecondClockValue.
	aCollectionOfPackages do: [ :package | self addIndex: (CooNeuralPackageIndex on: package) ].
	self prune.
	buildMicroseconds := Time microsecondClockValue - start
]

{ #category : 'accessing' }
CooNeuralCorpusStatistics >> buildMicroseconds [

	^ buildMicroseconds ifNil: [ 0 ]
]

{ #category : 'converting' }
CooNeuralCorpusStatistics >> fromDictionary: aDictionary [

	packageNames := (aDictionary at: #packageNames ifAbsent: [ #(  ) ]) asSet.
	selectorCounts := aDictionary at: #selectorCounts ifAbsent: [ Dictionary new ].
	pairCounts := aDictionary at: #pairCounts ifAbsent: [ Dictionary new ].
	receiverCounts := aDictionary at: #receiverCounts ifAbsent: [ Dictionary new ].
	globalCounts := aDictionary at: #globalCounts ifAbsent: [ Dictionary new ]
]

{ #category : 'counting' }
CooNeuralCorpusStatistics >> globalCount: aName [

	^ globalCounts at: aName ifAbsent: [ 0 ]
]

{ #category : 'testing' }
CooNeuralCorpusStatistics >> includesPackageNamed: aString [

	^ packageNames includes: aString asString
]

{ #category : 'initialization' }
CooNeuralCorpusStatistics >> initialize [

	super initialize.
	packageNames := Set new.
	selectorCounts := Dictionary new.
	pairCounts := Dictionary new.
	receiverCounts := Dictionary new.
	globalCounts := Dictionary new
]

{ #category : 'accessing' }
CooNeuralCorpusStatistics >> numberOfEntries [

	^ selectorCounts size + pairCounts size + receiverCounts size + globalCounts size
]

{ #category : 'accessing' }
CooNeuralCorpusStatistics >> packageNames [

	^ packageNames
]

{ #category : 'counting' }
CooNeuralCorpusStatistics >> pairCount: aPairKey [

	^ pairCounts at: aPairKey ifAbsent: [ 0 ]
]

{ #category : 'building' }
CooNeuralCorpusStatistics >> prune [

	| kept |
	kept := Dictionary new: pairCounts size // 2.
	pairCounts keysAndValuesDo: [ :pair :count | count >= 2 ifTrue: [ kept at: pair put: count ] ].
	pairCounts := kept
]

{ #category : 'counting' }
CooNeuralCorpusStatistics >> receiverCount: aReceiverKey [

	^ receiverCounts at: aReceiverKey ifAbsent: [ 0 ]
]

{ #category : 'counting' }
CooNeuralCorpusStatistics >> selectorCount: aSelector [

	^ selectorCounts at: aSelector ifAbsent: [ 0 ]
]
