"
I run the whole neural re-ranking experiment and write its results:

1. split the packages of the image into training, validation and test packages, by project
   (CooNeuralPackageSplit);
2. count the selectors and globals of the training packages (CooNeuralCorpusStatistics);
3. for each kind of completion (#message, #variable) and each heuristic configuration (#baseline,
   #semantics, #dependency): extract the training and validation queries with that configuration,
   train a network, keep its best epoch on the validation packages and save it in models/;
4. on the test packages, complete every request with the six configurations
   (Baseline, Baseline + Re-ranking, Semantics, Semantics + Re-ranking, Dependency, Dependency + Re-ranking),
   measuring the rank of the expected token, the time and the allocated memory (CooNeuralBenchmarkRunner);
5. write the reports (CooNeuralReport): summary.md / .csv / .tex, per prefix, per package, training
   curves, every request in benchmark/requests-<kind>.csv and results.ston.

    CooNeuralExperiment new run.                 the default experiment (takes a while)
    CooNeuralExperiment quick run.               a small one, to try
    CooNeuralExperiment runFromEnvironment.      the one of scripts/run-neural-benchmarks.sh (NR_* variables)

With #reuseModels: true, the models already in models/ are loaded instead of trained again.
"
Class {
	#name : 'CooNeuralExperiment',
	#superclass : 'Object',
	#instVars : [
		'outputDirectory',
		'modelsDirectory',
		'split',
		'testPackageNames',
		'trainPackageNames',
		'validationPackageNames',
		'maxTrainPackages',
		'maxValidationPackages',
		'maxTestPackages',
		'kinds',
		'baseNames',
		'poolSize',
		'trainCallsites',
		'validationCallsites',
		'testCallsites',
		'hiddenSize',
		'embeddingSize',
		'buckets',
		'epochs',
		'batchSize',
		'learningRate',
		'patience',
		'seed',
		'reuseModels',
		'statistics',
		'rerankers',
		'runners',
		'heapBytes',
		'startTime',
		'endTime',
		'logStream'
	],
	#category : 'NeuralReranking-Benchmarks-Experiment',
	#package : 'NeuralReranking-Benchmarks',
	#tag : 'Experiment'
}

{ #category : 'environment' }
CooNeuralExperiment class >> environmentAt: aName [

	| value |
	value := OSEnvironment current at: aName ifAbsent: [ nil ].
	(value isNil or: [ value trimBoth isEmpty ]) ifTrue: [ ^ nil ].
	^ value trimBoth
]

{ #category : 'instance creation' }
CooNeuralExperiment class >> fromEnvironment [
	"See scripts/run-neural-benchmarks.sh and the README for the NR_* variables."

	| experiment number list |
	experiment := (self environmentAt: 'NR_QUICK') = '1'
		              ifTrue: [ self quick ]
		              ifFalse: [ self new ].
	number := [ :name :setter |
	          (self environmentAt: name) ifNotNil: [ :value | experiment perform: setter with: value asNumber ] ].
	list := [ :name | (self environmentAt: name) ifNotNil: [ :value | (value substrings: ', ') asArray ] ].
	(self environmentAt: 'NR_OUTPUT') ifNotNil: [ :value | experiment outputDirectory: value ].
	(self environmentAt: 'NR_MODELS') ifNotNil: [ :value | experiment modelsDirectory: value ].
	(list value: 'NR_TEST_PACKAGES') ifNotNil: [ :names | experiment testPackageNames: names ].
	(list value: 'NR_TRAIN_PACKAGES') ifNotNil: [ :names | experiment trainPackageNames: names ].
	(list value: 'NR_VALIDATION_PACKAGES') ifNotNil: [ :names | experiment validationPackageNames: names ].
	(list value: 'NR_KINDS') ifNotNil: [ :names | experiment kinds: (names collect: [ :each | each asSymbol ]) ].
	(list value: 'NR_CONFIGURATIONS') ifNotNil: [ :names | experiment baseNames: (names collect: [ :each | each asSymbol ]) ].
	number value: 'NR_SEED' value: #seed:.
	number value: 'NR_MAX_TRAIN_PACKAGES' value: #maxTrainPackages:.
	number value: 'NR_MAX_VALIDATION_PACKAGES' value: #maxValidationPackages:.
	number value: 'NR_MAX_TEST_PACKAGES' value: #maxTestPackages:.
	number value: 'NR_TRAIN_CALLSITES' value: #trainCallsites:.
	number value: 'NR_VALIDATION_CALLSITES' value: #validationCallsites:.
	number value: 'NR_TEST_CALLSITES' value: #testCallsites:.
	number value: 'NR_POOL' value: #poolSize:.
	number value: 'NR_HIDDEN' value: #hiddenSize:.
	number value: 'NR_EMBEDDING' value: #embeddingSize:.
	number value: 'NR_BUCKETS' value: #buckets:.
	number value: 'NR_EPOCHS' value: #epochs:.
	number value: 'NR_BATCH' value: #batchSize:.
	number value: 'NR_LEARNING_RATE' value: #learningRate:.
	number value: 'NR_PATIENCE' value: #patience:.
	(self environmentAt: 'NR_REUSE_MODELS') ifNotNil: [ :value | experiment reuseModels: value = '1' ].
	^ experiment
]

{ #category : 'instance creation' }
CooNeuralExperiment class >> quick [
	"A small experiment, a few minutes: to try the pipeline, not for the paper."

	^ self new
		  maxTrainPackages: 8;
		  maxValidationPackages: 3;
		  maxTestPackages: 3;
		  trainCallsites: 25;
		  validationCallsites: 25;
		  testCallsites: 30;
		  epochs: 4;
		  yourself
]

{ #category : 'running' }
CooNeuralExperiment class >> runFromEnvironment [
	"Entry point of scripts/run-neural-benchmarks.sh. Warnings are resumed: nobody can answer them headless."

	^ [ self fromEnvironment run ]
		  on: Warning
		  do: [ :warning | warning resume: true ]
]

{ #category : 'accessing' }
CooNeuralExperiment >> baseNames [

	^ baseNames
]

{ #category : 'accessing' }
CooNeuralExperiment >> baseNames: aCollection [

	baseNames := aCollection asArray
]

{ #category : 'running' }
CooNeuralExperiment >> benchmark: aKind [

	| runner file |
	Smalltalk garbageCollect.
	heapBytes at: aKind put: (Array with: Smalltalk vm memorySize with: 0).
	runner := CooNeuralBenchmarkRunner new
		          kind: aKind;
		          configurations: (CooNeuralBenchmarkConfiguration allFor: baseNames);
		          rerankers: (Dictionary newFrom: (baseNames collect: [ :base | base -> (self rerankerFor: aKind base: base) ]));
		          callsitesPerPackage: testCallsites;
		          seed: seed;
		          logBlock: [ :string | self log: '  ' , string ];
		          yourself.
	file := outputDirectory / 'benchmark' / ('requests-' , aKind , '.csv').
	file parent ensureCreateDirectory.
	file ensureDelete.
	self log: '== Test: ' , aKind , ' completion, ' , self split testPackageNames size printString , ' packages, 6 configurations'.
	file writeStreamDo: [ :stream |
		stream
			nextPutAll: CooNeuralBenchmarkDriver csvHeader;
			lf.
		runner csvStream: stream.
		runner setUp.
		runner run: self split testPackages ].
	(heapBytes at: aKind) at: 2 put: Smalltalk vm memorySize.
	runners at: aKind put: runner.
	^ runner
]

{ #category : 'accessing' }
CooNeuralExperiment >> batchSize: anInteger [

	batchSize := anInteger
]

{ #category : 'accessing' }
CooNeuralExperiment >> buckets: anInteger [

	buckets := anInteger
]

{ #category : 'training' }
CooNeuralExperiment >> datasetFor: aTask base: aBaseName extractor: anExtractor callsites: aMaximum packages: somePackages [

	^ CooNeuralDatasetBuilder new
		  task: aTask;
		  builder: (CooNeuralHeuristics builderFor: aBaseName kind: aTask kind);
		  extractor: anExtractor;
		  poolSize: poolSize;
		  callsitesPerPackage: aMaximum;
		  seed: seed;
		  logBlock: [ :string | self log: '    ' , string ];
		  buildFor: somePackages
]

{ #category : 'accessing' }
CooNeuralExperiment >> embeddingSize: anInteger [

	embeddingSize := anInteger
]

{ #category : 'accessing' }
CooNeuralExperiment >> endTime [

	^ endTime
]

{ #category : 'accessing' }
CooNeuralExperiment >> epochs: anInteger [

	epochs := anInteger
]

{ #category : 'accessing' }
CooNeuralExperiment >> heapBytes [

	^ heapBytes
]

{ #category : 'accessing' }
CooNeuralExperiment >> hiddenSize: anInteger [

	hiddenSize := anInteger
]

{ #category : 'initialization' }
CooNeuralExperiment >> initialize [

	super initialize.
	outputDirectory := FileLocator workingDirectory / 'neural-results'.
	maxTrainPackages := 40.
	maxValidationPackages := 10.
	maxTestPackages := 15.
	kinds := CooNeuralTask kinds.
	baseNames := CooNeuralHeuristics configurationNames.
	poolSize := 20.
	trainCallsites := 50.
	validationCallsites := 50.
	testCallsites := 200.
	hiddenSize := 16.
	embeddingSize := 8.
	buckets := 4096.
	epochs := 8.
	batchSize := 16.
	learningRate := 0.005.
	patience := 3.
	seed := 42.
	reuseModels := false.
	rerankers := Dictionary new.
	runners := Dictionary new.
	heapBytes := Dictionary new
]

{ #category : 'accessing' }
CooNeuralExperiment >> kinds [

	^ kinds
]

{ #category : 'accessing' }
CooNeuralExperiment >> kinds: aCollection [

	kinds := aCollection asArray
]

{ #category : 'accessing' }
CooNeuralExperiment >> learningRate: aNumber [

	learningRate := aNumber asFloat
]

{ #category : 'logging' }
CooNeuralExperiment >> log: aString [

	| line |
	line := Time now print24 , ' ' , aString.
	Stdio stdout
		nextPutAll: line;
		lf;
		flush.
	logStream ifNotNil: [
		logStream
			nextPutAll: line;
			lf;
			flush ]
]

{ #category : 'accessing' }
CooNeuralExperiment >> maxTestPackages: anInteger [

	maxTestPackages := anInteger
]

{ #category : 'accessing' }
CooNeuralExperiment >> maxTrainPackages: anInteger [

	maxTrainPackages := anInteger
]

{ #category : 'accessing' }
CooNeuralExperiment >> maxValidationPackages: anInteger [

	maxValidationPackages := anInteger
]

{ #category : 'training' }
CooNeuralExperiment >> modelFileFor: aKind base: aBaseName [

	^ self modelsDirectory / (aKind , '-' , aBaseName , '.ston')
]

{ #category : 'accessing' }
CooNeuralExperiment >> modelsDirectory [

	^ modelsDirectory ifNil: [ outputDirectory / 'models' ]
]

{ #category : 'accessing' }
CooNeuralExperiment >> modelsDirectory: aFileReferenceOrString [

	modelsDirectory := aFileReferenceOrString asFileReference
]

{ #category : 'accessing' }
CooNeuralExperiment >> outputDirectory [

	^ outputDirectory
]

{ #category : 'accessing' }
CooNeuralExperiment >> outputDirectory: aFileReferenceOrString [

	outputDirectory := aFileReferenceOrString asFileReference
]

{ #category : 'accessing' }
CooNeuralExperiment >> patience: anInteger [

	patience := anInteger
]

{ #category : 'accessing' }
CooNeuralExperiment >> poolSize: anInteger [

	poolSize := anInteger
]

{ #category : 'accessing' }
CooNeuralExperiment >> rerankerFor: aKind base: aBaseName [

	^ rerankers
		  at: aKind -> aBaseName
		  ifAbsentPut: [ self trainOrLoadRerankerFor: aKind base: aBaseName ]
]

{ #category : 'accessing' }
CooNeuralExperiment >> rerankers [

	^ rerankers
]

{ #category : 'accessing' }
CooNeuralExperiment >> reuseModels: aBoolean [

	reuseModels := aBoolean
]

{ #category : 'running' }
CooNeuralExperiment >> run [

	startTime := DateAndTime now.
	outputDirectory ensureCreateDirectory.
	(outputDirectory / 'experiment.log') ensureDelete.
	(outputDirectory / 'experiment.log') writeStreamDo: [ :stream |
		logStream := stream.
		[
		self log: '== Neural re-ranking experiment, results in ' , outputDirectory fullName.
		self log: '== Split: ' , self split trainPackageNames size printString , ' training, '
			, self split validationPackageNames size printString , ' validation, '
			, self split testPackageNames size printString , ' test packages'.
		CooNeuralReport new
			experiment: self;
			writeSplit.
		kinds do: [ :kind | baseNames do: [ :base | self rerankerFor: kind base: base ] ].
		kinds do: [ :kind | self benchmark: kind ].
		endTime := DateAndTime now.
		CooNeuralReport new
			experiment: self;
			writeAll.
		self log: '== Done in ' , (endTime - startTime) printString , ', see ' , (outputDirectory / 'summary.md') fullName ]
			ensure: [ logStream := nil ] ]
]

{ #category : 'accessing' }
CooNeuralExperiment >> runners [

	^ runners
]

{ #category : 'accessing' }
CooNeuralExperiment >> seed [

	^ seed
]

{ #category : 'accessing' }
CooNeuralExperiment >> seed: anInteger [

	seed := anInteger
]

{ #category : 'accessing' }
CooNeuralExperiment >> settings [

	^ Dictionary new
		  at: #seed put: seed;
		  at: #kinds put: kinds;
		  at: #configurations put: baseNames;
		  at: #poolSize put: poolSize;
		  at: #maxTrainPackages put: maxTrainPackages;
		  at: #maxValidationPackages put: maxValidationPackages;
		  at: #maxTestPackages put: maxTestPackages;
		  at: #trainCallsitesPerPackage put: trainCallsites;
		  at: #validationCallsitesPerPackage put: validationCallsites;
		  at: #testCallsitesPerPackage put: testCallsites;
		  at: #hiddenSize put: hiddenSize;
		  at: #embeddingSize put: embeddingSize;
		  at: #buckets put: buckets;
		  at: #epochs put: epochs;
		  at: #batchSize put: batchSize;
		  at: #learningRate put: learningRate;
		  at: #patience put: patience;
		  at: #reuseModels put: reuseModels;
		  yourself
]

{ #category : 'accessing' }
CooNeuralExperiment >> split [

	^ split ifNil: [
		  split := trainPackageNames
			           ifNotNil: [
				           CooNeuralPackageSplit
					           train: trainPackageNames
					           validation: (validationPackageNames ifNil: [ #(  ) ])
					           test: (testPackageNames ifNil: [ #(  ) ]) ]
			           ifNil: [ CooNeuralPackageSplit fromImageWithSeed: seed testPackageNames: testPackageNames ].
		  split seed: seed.
		  "the package lists given explicitly are kept as they are"
		  split
			  maxTrain: (trainPackageNames ifNil: [ maxTrainPackages ] ifNotNil: [ nil ])
			  validation: (validationPackageNames ifNil: [ maxValidationPackages ] ifNotNil: [ nil ])
			  test: (testPackageNames ifNil: [ maxTestPackages ] ifNotNil: [ nil ]).
		  split ]
]

{ #category : 'accessing' }
CooNeuralExperiment >> split: aPackageSplit [

	split := aPackageSplit
]

{ #category : 'accessing' }
CooNeuralExperiment >> startTime [

	^ startTime
]

{ #category : 'training' }
CooNeuralExperiment >> statistics [

	^ statistics ifNil: [
		  self log: '== Corpus statistics of the training packages'.
		  statistics := CooNeuralCorpusStatistics buildFrom: self split trainPackages.
		  self log: '  ' , statistics numberOfEntries printString , ' entries in '
			  , (statistics buildMicroseconds / 1.0e6 printShowingDecimalPlaces: 1) , ' s'.
		  statistics ]
]

{ #category : 'accessing' }
CooNeuralExperiment >> testCallsites: anInteger [

	testCallsites := anInteger
]

{ #category : 'accessing' }
CooNeuralExperiment >> testPackageNames: aCollection [

	testPackageNames := aCollection asArray
]

{ #category : 'accessing' }
CooNeuralExperiment >> trainCallsites: anInteger [

	trainCallsites := anInteger
]

{ #category : 'training' }
CooNeuralExperiment >> trainOrLoadRerankerFor: aKind base: aBaseName [

	| file task extractor trainingSet validationSet model trainer summary reranker |
	file := self modelFileFor: aKind base: aBaseName.
	(reuseModels and: [ file exists ]) ifTrue: [
		self log: '== Loading ' , file fullName.
		^ CooNeuralReranker loadFrom: file ].
	self log: '== Training the ' , aKind , ' re-ranker of ' , aBaseName.
	task := CooNeuralTask forKind: aKind.
	extractor := task newFeatureExtractor
		             statistics: self statistics;
		             buckets: buckets;
		             leaveOneOut: true;
		             yourself.
	self log: '  training queries'.
	trainingSet := self
		               datasetFor: task
		               base: aBaseName
		               extractor: extractor
		               callsites: trainCallsites
		               packages: self split trainPackages.
	extractor
		leaveOneOut: false;
		resetPackageIndexes.
	self log: '  validation queries'.
	validationSet := self
		                 datasetFor: task
		                 base: aBaseName
		                 extractor: extractor
		                 callsites: validationCallsites
		                 packages: self split validationPackages.
	self log: '  ' , trainingSet size printString , ' training queries (' , trainingSet total printString
		, ' requests, ' , trainingSet errors printString , ' errors), ' , validationSet size printString
		, ' validation queries (' , validationSet total printString , ' requests)'.
	model := CooNeuralMLP
		         denseSize: extractor denseSize
		         fetcherNames: trainingSet fetcherNames
		         hiddenSize: hiddenSize
		         embeddingSize: embeddingSize
		         buckets: extractor buckets
		         seed: seed.
	trainer := CooNeuralTrainer new
		           model: model;
		           trainingSet: trainingSet;
		           validationSet: validationSet;
		           epochs: epochs;
		           batchSize: batchSize;
		           learningRate: learningRate;
		           patience: patience;
		           seed: seed;
		           logBlock: [ :string | self log: '  ' , string ];
		           yourself.
	trainer train.
	model releaseOptimizer.
	summary := trainer summary.
	summary
		at: #kind put: aKind;
		at: #configuration put: aBaseName;
		at: #poolSize put: poolSize;
		at: #history put: trainer history asArray;
		at: #trainingErrors put: trainingSet errors;
		at: #validationErrors put: validationSet errors;
		at: #model put: model printString.
	reranker := (CooNeuralReranker model: model extractor: extractor)
		            configurationName: aBaseName;
		            poolSize: poolSize;
		            trainingSummary: summary;
		            yourself.
	reranker saveTo: file.
	self log: '  saved ' , file fullName , ' (' , (file size / 1024) rounded printString , ' KB)'.
	^ reranker
]

{ #category : 'accessing' }
CooNeuralExperiment >> trainPackageNames: aCollection [

	trainPackageNames := aCollection asArray
]

{ #category : 'accessing' }
CooNeuralExperiment >> validationCallsites: anInteger [

	validationCallsites := anInteger
]

{ #category : 'accessing' }
CooNeuralExperiment >> validationPackageNames: aCollection [

	validationPackageNames := aCollection asArray
]
