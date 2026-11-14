Class {
	#name : 'CooNeuralFeatureTest',
	#superclass : 'TestCase',
	#category : 'NeuralReranking-Tests',
	#package : 'NeuralReranking-Tests'
}

{ #category : 'helpers' }
CooNeuralFeatureTest >> messageNodeSending: aSelector in: aMethodSelector [

	(CooNeuralFixture >> aMethodSelector) parseTree nodesDo: [ :node |
		(node isMessage and: [ node selector = aSelector ]) ifTrue: [ ^ node ] ].
	^ self error: 'no such send'
]

{ #category : 'helpers' }
CooNeuralFeatureTest >> package [

	^ CooNeuralFixture package
]

{ #category : 'tests' }
CooNeuralFeatureTest >> testFeaturesHaveTheDeclaredSize [

	CooNeuralTask kinds do: [ :kind |
		| task extractor callsites node entries query |
		task := CooNeuralTask forKind: kind.
		extractor := task newFeatureExtractor.
		callsites := task callsitesIn: self package.
		node := callsites detect: [ :each | (task targetOf: each) size >= 3 ].
		entries := task
			           candidatesFrom: (CooNeuralHeuristics builderFor: #semantics kind: kind)
			           for: node
			           position: (task positionOf: node)
			           prefix: ((task targetOf: node) copyFrom: 1 to: 2)
			           size: 5.
		query := extractor
			         queryFor: entries
			         prefix: ((task targetOf: node) copyFrom: 1 to: 2)
			         node: node
			         completionClass: (task completionClassOf: node).
		self assert: query size equals: entries size.
		query candidates do: [ :candidate |
			self assert: candidate dense size equals: extractor featureNames size.
			self assert: (candidate ids allSatisfy: [ :id | id between: 1 and: extractor buckets ]) ] ]
]

{ #category : 'tests' }
CooNeuralFeatureTest >> testPackageCountsExcludeTheCurrentMethod [
	"In a static benchmark the method is already written: its own sends must not be seen by the features."

	| index |
	index := CooNeuralPackageIndex on: self package.
	self assert: (index sendCountOf: #cooNeuralUniqueSelector excludingMethod: 'CooNeuralFixture>>alpha') equals: 0.
	self assert: (index sendCountOf: #cooNeuralSharedSelector excludingMethod: 'CooNeuralFixture>>beta') equals: 1.
	self assert: (index sendCountOf: #cooNeuralSharedSelector excludingMethod: 'CooNeuralFixture>>alpha') equals: 2.
	self
		assert: (index globalCountOf: #OrderedCollection excludingMethod: 'CooNeuralFixture>>gamma')
		equals: ((index globals occurrencesOf: #OrderedCollection) - 1)
]

{ #category : 'tests' }
CooNeuralFeatureTest >> testPackageFeatureOfTheTargetIgnoresItsOwnCallsite [

	| extractor node query names |
	extractor := CooNeuralMessageFeatureExtractor new.
	names := extractor featureNames.
	node := self messageNodeSending: #cooNeuralUniqueSelector in: #alpha.
	query := extractor
		         queryFor: { (CoSelectorEntry contents: #cooNeuralUniqueSelector node: nil) }
		         prefix: 'coo'
		         node: node
		         completionClass: CooNeuralFixture.
	self assert: (query candidates first dense at: (names indexOf: 'package-used')) equals: 0.0.
	node := self messageNodeSending: #cooNeuralSharedSelector in: #beta.
	query := extractor
		         queryFor: { (CoSelectorEntry contents: #cooNeuralSharedSelector node: nil) }
		         prefix: 'coo'
		         node: node
		         completionClass: CooNeuralFixture.
	self assert: (query candidates first dense at: (names indexOf: 'package-used')) equals: 1.0
]

{ #category : 'tests' }
CooNeuralFeatureTest >> testReceiverKeys [

	| node |
	node := self messageNodeSending: #cooNeuralUniqueSelector in: #alpha.
	self assert: (CooNeuralMessageFeatureExtractor receiverKeyOf: node) equals: 'self'.
	node := self messageNodeSending: #size in: #gamma.
	self assert: (CooNeuralMessageFeatureExtractor receiverKeyOf: node) equals: 'message:new'.
	node := self messageNodeSending: #new in: #gamma.
	self assert: (CooNeuralMessageFeatureExtractor receiverKeyOf: node) equals: 'global:OrderedCollection'
]

{ #category : 'tests' }
CooNeuralFeatureTest >> testStatisticsLeaveOneOut [

	| statistics extractor node query names |
	statistics := CooNeuralCorpusStatistics buildFrom: { self package }.
	extractor := CooNeuralMessageFeatureExtractor new
		             statistics: statistics;
		             leaveOneOut: true;
		             yourself.
	names := extractor featureNames.
	node := self messageNodeSending: #cooNeuralUniqueSelector in: #alpha.
	query := extractor
		         queryFor: { (CoSelectorEntry contents: #cooNeuralUniqueSelector node: nil) }
		         prefix: 'coo'
		         node: node
		         completionClass: CooNeuralFixture.
	self assert: (query candidates first dense at: (names indexOf: 'corpus-frequency')) equals: 0.0.
	extractor leaveOneOut: false.
	query := extractor
		         queryFor: { (CoSelectorEntry contents: #cooNeuralUniqueSelector node: nil) }
		         prefix: 'coo'
		         node: node
		         completionClass: CooNeuralFixture.
	self assert: (query candidates first dense at: (names indexOf: 'corpus-frequency')) > 0.0
]
