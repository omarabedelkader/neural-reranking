"
I extract a CooNeuralDataset from packages: for (a sample of) the call sites of every package and every
prefix of 2 to 8 characters, I ask the heuristic builder for the first poolSize candidates, exactly like
the benchmark does, and turn them into a CooNeuralQuery with the index of the expected token.

    (CooNeuralDatasetBuilder new
        task: (CooNeuralTask forKind: #message);
        builder: (CooNeuralHeuristics builderFor: #semantics kind: #message);
        extractor: anExtractor;
        poolSize: 20;
        callsitesPerPackage: 50;
        seed: 42;
        yourself) buildFor: somePackages.
"
Class {
	#name : 'CooNeuralDatasetBuilder',
	#superclass : 'Object',
	#instVars : [
		'task',
		'builder',
		'extractor',
		'poolSize',
		'callsitesPerPackage',
		'seed',
		'logBlock'
	],
	#category : 'NeuralReranking-Training',
	#package : 'NeuralReranking-Training'
}

{ #category : 'building' }
CooNeuralDatasetBuilder >> add: aNode target: aToken prefixSize: aSize to: aDataset [

	| prefix entries rank position |
	prefix := aToken copyFrom: 1 to: aSize.
	position := task positionOf: aNode.
	task setPrefix: prefix on: aNode.
	[
	[
	entries := task
		           candidatesFrom: builder
		           for: aNode
		           position: position
		           prefix: prefix
		           size: poolSize.
	rank := task rankOf: aToken in: entries.
	rank = 0
		ifTrue: [ aDataset addMissing ]
		ifFalse: [
			aDataset addQuery: ((extractor
					  queryFor: entries
					  prefix: prefix
					  node: aNode
					  completionClass: (task completionClassOf: aNode))
					 targetIndex: rank;
					 yourself) ] ]
		on: Error
		do: [ :error | aDataset addError: error ] ] ensure: [ task restore: aToken on: aNode ]
]

{ #category : 'building' }
CooNeuralDatasetBuilder >> buildFor: aCollectionOfPackages [

	| dataset start |
	dataset := CooNeuralDataset new.
	start := Time microsecondClockValue.
	aCollectionOfPackages do: [ :package |
		| callsites before |
		before := dataset total.
		extractor prepareForPackage: package.
		callsites := task
			             sample: (task callsitesIn: package)
			             max: callsitesPerPackage
			             seed: seed
			             salt: package name.
		callsites do: [ :node |
			| target |
			target := task targetOf: node.
			2 to: (task maxPrefixSizeFor: target) do: [ :size |
			self
				add: node
				target: target
				prefixSize: size
				to: dataset ] ].
		dataset addPackageName: package name asString.
		extractor forgetPackage: package.
		self log: package name , ': ' , (dataset total - before) printString , ' requests' ].
	dataset extractionMicroseconds: Time microsecondClockValue - start.
	^ dataset
]

{ #category : 'accessing' }
CooNeuralDatasetBuilder >> builder: aResultSetBuilder [

	builder := aResultSetBuilder
]

{ #category : 'accessing' }
CooNeuralDatasetBuilder >> callsitesPerPackage: anIntegerOrNil [

	callsitesPerPackage := anIntegerOrNil
]

{ #category : 'accessing' }
CooNeuralDatasetBuilder >> extractor: aFeatureExtractor [

	extractor := aFeatureExtractor
]

{ #category : 'initialization' }
CooNeuralDatasetBuilder >> initialize [

	super initialize.
	poolSize := 20.
	callsitesPerPackage := 50.
	seed := 42
]

{ #category : 'logging' }
CooNeuralDatasetBuilder >> log: aString [

	logBlock ifNotNil: [ logBlock value: aString ]
]

{ #category : 'accessing' }
CooNeuralDatasetBuilder >> logBlock: aBlock [

	logBlock := aBlock
]

{ #category : 'accessing' }
CooNeuralDatasetBuilder >> poolSize: anInteger [

	poolSize := anInteger
]

{ #category : 'accessing' }
CooNeuralDatasetBuilder >> seed: anInteger [

	seed := anInteger
]

{ #category : 'accessing' }
CooNeuralDatasetBuilder >> task: aTask [

	task := aTask
]
