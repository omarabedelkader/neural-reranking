"
I train a CooNeuralMLP on a training CooNeuralDataset and select it on a validation one.

- the dense features are standardized on the training queries;
- every epoch goes over the shuffled training queries in mini-batches (Adam, listwise softmax loss);
- after every epoch the network is evaluated on the validation queries (MRR@10 over all the validation
  requests, the ones whose expected token is not in the pool count as failures);
- the weights of the best epoch are kept, and training stops after #patience epochs without improvement.

My history has one line per epoch (training loss, validation MRR, Recall@1/3/10), and the same measures
for the order of the heuristics (base*), which is what the re-ranker must beat.
"
Class {
	#name : 'CooNeuralTrainer',
	#superclass : 'Object',
	#instVars : [
		'model',
		'trainingSet',
		'validationSet',
		'epochs',
		'batchSize',
		'learningRate',
		'patience',
		'seed',
		'history',
		'bestEpoch',
		'bestEvaluation',
		'trainingMicroseconds',
		'logBlock'
	],
	#category : 'NeuralReranking-Training',
	#package : 'NeuralReranking-Training'
}

{ #category : 'accessing' }
CooNeuralTrainer >> batchSize: anInteger [

	batchSize := anInteger
]

{ #category : 'accessing' }
CooNeuralTrainer >> bestEpoch [

	^ bestEpoch
]

{ #category : 'accessing' }
CooNeuralTrainer >> bestEvaluation [

	^ bestEvaluation
]

{ #category : 'accessing' }
CooNeuralTrainer >> epochs: anInteger [

	epochs := anInteger
]

{ #category : 'evaluating' }
CooNeuralTrainer >> evaluate: aDataset [
	"MRR@10 and Recall@k of the network and of the order of the heuristics, over all the requests of aDataset."

	| total reranked base |
	total := aDataset total.
	reranked := Array new: 4 withAll: 0.0.
	base := Array new: 4 withAll: 0.0.
	aDataset queries do: [ :query |
		| rank |
		rank := query size < 2
			        ifTrue: [ 1 ]
			        ifFalse: [ self rankOfTargetIn: (model scoresOf: query) target: query targetIndex ].
		self add: rank to: reranked.
		self add: query targetIndex to: base ].
	total = 0 ifTrue: [ total := 1 ].
	^ Dictionary new
		  at: #mrr put: reranked first / total;
		  at: #recall1 put: reranked second / total;
		  at: #recall3 put: reranked third / total;
		  at: #recall10 put: reranked fourth / total;
		  at: #baseMrr put: base first / total;
		  at: #baseRecall1 put: base second / total;
		  at: #baseRecall3 put: base third / total;
		  at: #baseRecall10 put: base fourth / total;
		  at: #requests put: aDataset total;
		  at: #inPool put: aDataset size;
		  yourself
]

{ #category : 'accessing' }
CooNeuralTrainer >> history [

	^ history
]

{ #category : 'initialization' }
CooNeuralTrainer >> initialize [

	super initialize.
	epochs := 8.
	batchSize := 16.
	learningRate := 0.005.
	patience := 3.
	seed := 42.
	history := OrderedCollection new
]

{ #category : 'accessing' }
CooNeuralTrainer >> learningRate: aFloat [

	learningRate := aFloat
]

{ #category : 'logging' }
CooNeuralTrainer >> log: aString [

	logBlock ifNotNil: [ logBlock value: aString ]
]

{ #category : 'accessing' }
CooNeuralTrainer >> logBlock: aBlock [

	logBlock := aBlock
]

{ #category : 'accessing' }
CooNeuralTrainer >> model [

	^ model
]

{ #category : 'accessing' }
CooNeuralTrainer >> model: aModel [

	model := aModel
]

{ #category : 'accessing' }
CooNeuralTrainer >> patience: anInteger [

	patience := anInteger
]

{ #category : 'evaluating' }
CooNeuralTrainer >> rankOfTargetIn: someScores target: aTargetIndex [
	"Ties are broken by the order of the heuristics, as in CooNeuralReranker>>#rerank:prefix:node:completionClass:."

	| targetScore rank |
	targetScore := someScores at: aTargetIndex.
	rank := 1.
	someScores doWithIndex: [ :score :index |
		(score > targetScore or: [ score = targetScore and: [ index < aTargetIndex ] ]) ifTrue: [ rank := rank + 1 ] ].
	^ rank
]

{ #category : 'accessing' }
CooNeuralTrainer >> seed: anInteger [

	seed := anInteger
]

{ #category : 'accessing' }
CooNeuralTrainer >> summary [

	^ Dictionary new
		  at: #epochs put: history size - 1;
		  at: #bestEpoch put: bestEpoch;
		  at: #batchSize put: batchSize;
		  at: #learningRate put: learningRate;
		  at: #patience put: patience;
		  at: #seed put: seed;
		  at: #trainingQueries put: trainingSet size;
		  at: #trainingRequests put: trainingSet total;
		  at: #trainingPackages put: trainingSet packageNames asArray;
		  at: #validationRequests put: validationSet total;
		  at: #validationPackages put: validationSet packageNames asArray;
		  at: #validation put: bestEvaluation;
		  at: #trainingSeconds put: self trainingSeconds;
		  at: #extractionSeconds
		  put: trainingSet extractionMicroseconds + validationSet extractionMicroseconds / 1.0e6;
		  yourself
]

{ #category : 'training' }
CooNeuralTrainer >> train [

	| start queries random bestParameters stale untrained |
	start := Time microsecondClockValue.
	queries := (trainingSet queries select: [ :query | query size >= 2 ]) asArray.
	model normalizeWith: queries.
	random := Random seed: seed.
	history := OrderedCollection new.
	untrained := self evaluate: validationSet.
	untrained
		at: #epoch put: 0;
		at: #loss put: 0.0.
	history add: untrained.
	self log: 'epoch 0 (untrained): validation MRR ' , ((history last at: #mrr) printShowingDecimalPlaces: 4)
		, ' (heuristics ' , ((history last at: #baseMrr) printShowingDecimalPlaces: 4) , ')'.
	stale := 0.
	1 to: epochs do: [ :epoch |
		| order loss evaluation |
		order := queries copy shuffleBy: random.
		loss := 0.0.
		1 to: order size by: batchSize do: [ :first |
			| last |
			last := first + batchSize - 1 min: order size.
			first to: last do: [ :index | loss := loss + (model accumulateGradientsOf: (order at: index)) ].
			model applyGradientsWithLearningRate: learningRate batchSize: last - first + 1 ].
		evaluation := self evaluate: validationSet.
		evaluation
			at: #epoch put: epoch;
			at: #loss put: loss / (order size max: 1).
		history add: evaluation.
		self log: 'epoch ' , epoch printString , ': loss ' , ((evaluation at: #loss) printShowingDecimalPlaces: 4)
			, ', validation MRR ' , ((evaluation at: #mrr) printShowingDecimalPlaces: 4).
		(bestParameters isNil or: [ (evaluation at: #mrr) > (bestEvaluation at: #mrr) ])
			ifTrue: [
				bestParameters := model parameters.
				bestEvaluation := evaluation.
				bestEpoch := epoch.
				stale := 0 ]
			ifFalse: [ stale := stale + 1 ].
		(stale >= patience or: [ epoch = epochs ]) ifTrue: [
			model parameters: bestParameters.
			trainingMicroseconds := Time microsecondClockValue - start.
			^ self ] ].
	bestParameters ifNotNil: [ model parameters: bestParameters ].
	bestEvaluation ifNil: [ bestEvaluation := history last ].
	bestEpoch ifNil: [ bestEpoch := 0 ].
	trainingMicroseconds := Time microsecondClockValue - start
]

{ #category : 'accessing' }
CooNeuralTrainer >> trainingMicroseconds [

	^ trainingMicroseconds ifNil: [ 0 ]
]

{ #category : 'accessing' }
CooNeuralTrainer >> trainingSeconds [

	^ self trainingMicroseconds / 1.0e6
]

{ #category : 'accessing' }
CooNeuralTrainer >> trainingSet: aDataset [

	trainingSet := aDataset
]

{ #category : 'accessing' }
CooNeuralTrainer >> validationSet: aDataset [

	validationSet := aDataset
]

{ #category : 'private' }
CooNeuralTrainer >> add: aRank to: someSums [

	aRank <= 10 ifTrue: [ someSums at: 1 put: someSums first + (1.0 / aRank) ].
	aRank = 1 ifTrue: [ someSums at: 2 put: someSums second + 1 ].
	aRank <= 3 ifTrue: [ someSums at: 3 put: someSums third + 1 ].
	aRank <= 10 ifTrue: [ someSums at: 4 put: someSums fourth + 1 ]
]
