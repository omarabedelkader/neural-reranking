"
I am the small neural network that scores completion candidates.

For a candidate c of a query q, my input is

    x = [ normalized dense features of c ; one-hot of the fetcher of c ; e(c) ; e(c) * e(q) ]

where e(c) is the mean of the embeddings of the hashed sub-words of the candidate, e(q) the mean of the
embeddings of the hashed sub-words of the context, and * the element-wise product (an interaction between
candidate and context). Then

    h = relu(W1 x + b1)        score = w2 . h + b2

The candidates of a query are ranked by decreasing score. I am trained with a listwise loss: the softmax
cross-entropy of the expected candidate among the candidates of the query (#accumulateGradientsOf:),
optimized with Adam (lazy for the embedding rows, only the rows used in a batch are updated).

Everything is plain Smalltalk (Arrays of Floats), so I run in any Pharo image without plugin, and my
time and memory are measured by the benchmarks like any other completion code.
"
Class {
	#name : 'CooNeuralMLP',
	#superclass : 'Object',
	#instVars : [
		'denseSize',
		'fetcherNames',
		'fetcherIndexes',
		'hiddenSize',
		'embeddingSize',
		'buckets',
		'w1',
		'b1',
		'w2',
		'b2',
		'embeddings',
		'means',
		'scales',
		'gw1',
		'gb1',
		'gw2',
		'gb2',
		'gEmbeddings',
		'mw1',
		'vw1',
		'mb1',
		'vb1',
		'mw2',
		'vw2',
		'mb2',
		'vb2',
		'mEmbeddings',
		'vEmbeddings',
		'step'
	],
	#category : 'NeuralReranking-Core-Model',
	#package : 'NeuralReranking-Core',
	#tag : 'Model'
}

{ #category : 'instance creation' }
CooNeuralMLP class >> denseSize: aDenseSize fetcherNames: aCollection hiddenSize: aHiddenSize embeddingSize: anEmbeddingSize buckets: aNumberOfBuckets seed: aSeed [

	^ self new
		  setDenseSize: aDenseSize
		  fetcherNames: aCollection
		  hiddenSize: aHiddenSize
		  embeddingSize: anEmbeddingSize
		  buckets: aNumberOfBuckets;
		  initializeWeightsWithSeed: aSeed;
		  yourself
]

{ #category : 'instance creation' }
CooNeuralMLP class >> fromDictionary: aDictionary [

	^ self new
		  fromDictionary: aDictionary;
		  yourself
]

{ #category : 'training' }
CooNeuralMLP >> accumulateGradientsOf: aQuery [
	"Add the gradients of the softmax cross-entropy of the expected candidate of aQuery; answer the loss."

	| target contextEmbedding inputs hiddens scores maxScore exps total contextGradient |
	target := aQuery targetIndex.
	contextEmbedding := self embeddingOf: aQuery contextIds.
	inputs := aQuery candidates collect: [ :candidate | self inputOf: candidate context: contextEmbedding ].
	hiddens := inputs collect: [ :input | self hiddenOf: input first ].
	scores := hiddens collect: [ :hidden | self scoreOfHidden: hidden ].
	maxScore := scores max.
	exps := scores collect: [ :score | (score - maxScore) exp ].
	total := exps sum.
	contextGradient := Array new: embeddingSize withAll: 0.0.
	1 to: scores size do: [ :j |
		| gradient |
		gradient := (exps at: j) / total.
		j = target ifTrue: [ gradient := gradient - 1.0 ].
		self
			backward: gradient
			input: (inputs at: j)
			hidden: (hiddens at: j)
			candidate: (aQuery candidates at: j)
			context: contextEmbedding
			into: contextGradient ].
	self distribute: contextGradient over: aQuery contextIds.
	^ total ln + maxScore - (scores at: target)
]

{ #category : 'private' }
CooNeuralMLP >> adam: parameters gradient: gradients first: firstMoments second: secondMoments rate: aLearningRate scale: aBatchSize correction1: correction1 correction2: correction2 [

	1 to: parameters size do: [ :i |
		| gradient first second |
		gradient := (gradients at: i) / aBatchSize.
		first := 0.9 * (firstMoments at: i) + (0.1 * gradient).
		second := 0.999 * (secondMoments at: i) + (0.001 * gradient * gradient).
		firstMoments at: i put: first.
		secondMoments at: i put: second.
		parameters
			at: i
			put: (parameters at: i) - (aLearningRate * (first / correction1) / ((second / correction2) sqrt + 1.0e-8)) ]
]

{ #category : 'training' }
CooNeuralMLP >> applyGradientsWithLearningRate: aLearningRate batchSize: aBatchSize [

	| correction1 correction2 update |
	aBatchSize = 0 ifTrue: [ ^ self ].
	step := step + 1.
	correction1 := 1.0 - (0.9 raisedTo: step).
	correction2 := 1.0 - (0.999 raisedTo: step).
	update := [ :parameters :gradients :first :second |
	          self
		          adam: parameters
		          gradient: gradients
		          first: first
		          second: second
		          rate: aLearningRate
		          scale: aBatchSize
		          correction1: correction1
		          correction2: correction2 ].
	1 to: hiddenSize do: [ :k | update value: (w1 at: k) value: (gw1 at: k) value: (mw1 at: k) value: (vw1 at: k) ].
	update value: b1 value: gb1 value: mb1 value: vb1.
	update value: w2 value: gw2 value: mw2 value: vw2.
	update value: b2 value: gb2 value: mb2 value: vb2.
	gEmbeddings keysAndValuesDo: [ :id :gradient |
		update
			value: (embeddings at: id)
			value: gradient
			value: (mEmbeddings at: id ifAbsentPut: [ self zerosOfSize: embeddingSize ])
			value: (vEmbeddings at: id ifAbsentPut: [ self zerosOfSize: embeddingSize ]) ].
	self zeroGradients
]

{ #category : 'converting' }
CooNeuralMLP >> asDictionary [

	^ Dictionary new
		  at: #denseSize put: denseSize;
		  at: #fetcherNames put: fetcherNames;
		  at: #hiddenSize put: hiddenSize;
		  at: #embeddingSize put: embeddingSize;
		  at: #buckets put: buckets;
		  at: #w1 put: w1;
		  at: #b1 put: b1;
		  at: #w2 put: w2;
		  at: #b2 put: b2;
		  at: #embeddings put: embeddings;
		  at: #means put: means;
		  at: #scales put: scales;
		  yourself
]

{ #category : 'private' }
CooNeuralMLP >> backward: aGradient input: anInput hidden: aHidden candidate: aCandidate context: aContextEmbedding into: aContextGradient [

	| x candidateEmbedding offset embeddingGradient candidateGradient |
	x := anInput first.
	candidateEmbedding := anInput second.
	offset := self embeddingOffset.
	embeddingGradient := self zerosOfSize: 2 * embeddingSize.
	gb2 at: 1 put: (gb2 at: 1) + aGradient.
	1 to: hiddenSize do: [ :k |
		| activation |
		activation := aHidden at: k.
		activation > 0.0 ifTrue: [
			| gradient row rowGradient |
			gw2 at: k put: (gw2 at: k) + (aGradient * activation).
			gradient := aGradient * (w2 at: k).
			gb1 at: k put: (gb1 at: k) + gradient.
			row := w1 at: k.
			rowGradient := gw1 at: k.
			1 to: x size do: [ :i | rowGradient at: i put: (rowGradient at: i) + (gradient * (x at: i)) ].
			1 to: 2 * embeddingSize do: [ :i |
				embeddingGradient at: i put: (embeddingGradient at: i) + (gradient * (row at: offset + i)) ] ] ].
	candidateGradient := (1 to: embeddingSize) collect: [ :i |
		                     (embeddingGradient at: i)
		                     + ((embeddingGradient at: embeddingSize + i) * (aContextEmbedding at: i)) ].
	1 to: embeddingSize do: [ :i |
		aContextGradient
			at: i
			put: (aContextGradient at: i) + ((embeddingGradient at: embeddingSize + i) * (candidateEmbedding at: i)) ].
	self distribute: candidateGradient over: aCandidate ids
]

{ #category : 'accessing' }
CooNeuralMLP >> buckets [

	^ buckets
]

{ #category : 'accessing' }
CooNeuralMLP >> denseSize [

	^ denseSize
]

{ #category : 'private' }
CooNeuralMLP >> distribute: aGradient over: someIds [

	someIds isEmpty ifTrue: [ ^ self ].
	someIds do: [ :id |
		| row |
		row := gEmbeddings at: id ifAbsentPut: [ self zerosOfSize: embeddingSize ].
		1 to: embeddingSize do: [ :i | row at: i put: (row at: i) + ((aGradient at: i) / someIds size) ] ]
]

{ #category : 'scoring' }
CooNeuralMLP >> embeddingOf: someIds [

	| result |
	result := self zerosOfSize: embeddingSize.
	someIds isEmpty ifTrue: [ ^ result ].
	someIds do: [ :id |
		| row |
		row := embeddings at: id.
		1 to: embeddingSize do: [ :i | result at: i put: (result at: i) + (row at: i) ] ].
	1 to: embeddingSize do: [ :i | result at: i put: (result at: i) / someIds size ].
	^ result
]

{ #category : 'private' }
CooNeuralMLP >> embeddingOffset [

	^ denseSize + fetcherNames size + 1
]

{ #category : 'accessing' }
CooNeuralMLP >> embeddingSize [

	^ embeddingSize
]

{ #category : 'accessing' }
CooNeuralMLP >> embeddings [

	^ embeddings
]

{ #category : 'accessing' }
CooNeuralMLP >> fetcherNames [

	^ fetcherNames
]

{ #category : 'scoring' }
CooNeuralMLP >> fetcherSlotOf: aFetcherName [

	^ fetcherIndexes at: aFetcherName asString ifAbsent: [ fetcherNames size + 1 ]
]

{ #category : 'converting' }
CooNeuralMLP >> fromDictionary: aDictionary [

	self
		setDenseSize: (aDictionary at: #denseSize)
		fetcherNames: (aDictionary at: #fetcherNames)
		hiddenSize: (aDictionary at: #hiddenSize)
		embeddingSize: (aDictionary at: #embeddingSize)
		buckets: (aDictionary at: #buckets).
	w1 := (aDictionary at: #w1) asArray collect: [ :row | row asArray ].
	b1 := (aDictionary at: #b1) asArray.
	w2 := (aDictionary at: #w2) asArray.
	b2 := (aDictionary at: #b2) asArray.
	embeddings := (aDictionary at: #embeddings) asArray collect: [ :row | row asArray ].
	means := (aDictionary at: #means) asArray.
	scales := (aDictionary at: #scales) asArray.
	self resetOptimizer
]

{ #category : 'accessing' }
CooNeuralMLP >> gradientOfB2 [

	^ gb2 first
]

{ #category : 'accessing' }
CooNeuralMLP >> gradientOfEmbedding: anId at: anIndex [

	^ (gEmbeddings at: anId ifAbsent: [ ^ 0.0 ]) at: anIndex
]

{ #category : 'accessing' }
CooNeuralMLP >> gradientOfW1At: aRow at: aColumn [

	^ (gw1 at: aRow) at: aColumn
]

{ #category : 'accessing' }
CooNeuralMLP >> gradientOfW2At: anIndex [

	^ gw2 at: anIndex
]

{ #category : 'scoring' }
CooNeuralMLP >> hiddenOf: anInput [

	^ (1 to: hiddenSize) collect: [ :k |
		  | row sum |
		  row := w1 at: k.
		  sum := b1 at: k.
		  1 to: anInput size do: [ :i | sum := sum + ((row at: i) * (anInput at: i)) ].
		  sum max: 0.0 ]
]

{ #category : 'accessing' }
CooNeuralMLP >> hiddenSize [

	^ hiddenSize
]

{ #category : 'initialization' }
CooNeuralMLP >> initializeWeightsWithSeed: aSeed [

	| random gaussian inputSize |
	random := Random seed: aSeed.
	gaussian := [
	            | u1 u2 |
	            u1 := random next max: 1.0e-12.
	            u2 := random next.
	            (-2.0 * u1 ln) sqrt * (2.0 * Float pi * u2) cos ].
	inputSize := self inputSize.
	w1 := (1 to: hiddenSize) collect: [ :k |
		      (1 to: inputSize) collect: [ :i | gaussian value * (2.0 / inputSize) sqrt ] ].
	b1 := self zerosOfSize: hiddenSize.
	w2 := (1 to: hiddenSize) collect: [ :k | gaussian value * (1.0 / hiddenSize) sqrt ].
	b2 := self zerosOfSize: 1.
	embeddings := (1 to: buckets) collect: [ :k | (1 to: embeddingSize) collect: [ :i | gaussian value * 0.1 ] ].
	means := self zerosOfSize: denseSize.
	scales := Array new: denseSize withAll: 1.0.
	self resetOptimizer
]

{ #category : 'scoring' }
CooNeuralMLP >> inputOf: aCandidate context: aContextEmbedding [
	"Answer the input vector of aCandidate and the embedding of the candidate (needed by the backward pass)."

	| x dense offset candidateEmbedding |
	x := self zerosOfSize: self inputSize.
	dense := aCandidate dense.
	1 to: denseSize do: [ :i | x at: i put: (dense at: i) - (means at: i) * (scales at: i) ].
	x at: denseSize + (self fetcherSlotOf: aCandidate fetcher) put: 1.0.
	offset := self embeddingOffset.
	candidateEmbedding := self embeddingOf: aCandidate ids.
	1 to: embeddingSize do: [ :i |
		x at: offset + i put: (candidateEmbedding at: i).
		x at: offset + embeddingSize + i put: (candidateEmbedding at: i) * (aContextEmbedding at: i) ].
	^ {
		  x.
		  candidateEmbedding }
]

{ #category : 'accessing' }
CooNeuralMLP >> inputSize [

	^ self embeddingOffset + (2 * embeddingSize)
]

{ #category : 'training' }
CooNeuralMLP >> lossOf: aQuery [

	| scores maxScore |
	scores := self scoresOf: aQuery.
	maxScore := scores max.
	^ (scores inject: 0.0 into: [ :sum :score | sum + (score - maxScore) exp ]) ln + maxScore
	  - (scores at: aQuery targetIndex)
]

{ #category : 'accessing' }
CooNeuralMLP >> means [

	^ means
]

{ #category : 'training' }
CooNeuralMLP >> normalizeWith: aCollectionOfQueries [
	"Standardize the dense features with their mean and standard deviation on the training queries."

	| count sums squares |
	count := 0.
	sums := self zerosOfSize: denseSize.
	squares := self zerosOfSize: denseSize.
	aCollectionOfQueries do: [ :query |
		query candidates do: [ :candidate |
			count := count + 1.
			1 to: denseSize do: [ :i |
				| value |
				value := candidate dense at: i.
				sums at: i put: (sums at: i) + value.
				squares at: i put: (squares at: i) + (value * value) ] ] ].
	count = 0 ifTrue: [ ^ self ].
	1 to: denseSize do: [ :i |
		| mean deviation |
		mean := (sums at: i) / count.
		deviation := ((squares at: i) / count - (mean * mean) max: 0.0) sqrt.
		means at: i put: mean.
		scales at: i put: (deviation < 1.0e-6
				 ifTrue: [ 1.0 ]
				 ifFalse: [ 1.0 / deviation ]) ]
]

{ #category : 'accessing' }
CooNeuralMLP >> numberOfParameters [

	^ hiddenSize * self inputSize + hiddenSize + hiddenSize + 1 + (buckets * embeddingSize)
]

{ #category : 'training' }
CooNeuralMLP >> parameters [
	"A copy of the weights, to keep the best model while training."

	^ {
		  (w1 collect: [ :row | row copy ]).
		  b1 copy.
		  w2 copy.
		  b2 copy.
		  (embeddings collect: [ :row | row copy ]) }
]

{ #category : 'training' }
CooNeuralMLP >> parameters: anArray [

	w1 := anArray first collect: [ :row | row copy ].
	b1 := anArray second copy.
	w2 := anArray third copy.
	b2 := anArray fourth copy.
	embeddings := anArray fifth collect: [ :row | row copy ]
]

{ #category : 'printing' }
CooNeuralMLP >> printOn: aStream [

	super printOn: aStream.
	aStream
		nextPut: $(;
		print: self inputSize;
		nextPutAll: ' -> ';
		print: hiddenSize;
		nextPutAll: ' -> 1, ';
		print: self numberOfParameters;
		nextPutAll: ' parameters)'
]

{ #category : 'training' }
CooNeuralMLP >> resetOptimizer [

	| inputSize |
	inputSize := self inputSize.
	step := 0.
	gw1 := (1 to: hiddenSize) collect: [ :k | self zerosOfSize: inputSize ].
	mw1 := (1 to: hiddenSize) collect: [ :k | self zerosOfSize: inputSize ].
	vw1 := (1 to: hiddenSize) collect: [ :k | self zerosOfSize: inputSize ].
	gb1 := self zerosOfSize: hiddenSize.
	mb1 := self zerosOfSize: hiddenSize.
	vb1 := self zerosOfSize: hiddenSize.
	gw2 := self zerosOfSize: hiddenSize.
	mw2 := self zerosOfSize: hiddenSize.
	vw2 := self zerosOfSize: hiddenSize.
	gb2 := self zerosOfSize: 1.
	mb2 := self zerosOfSize: 1.
	vb2 := self zerosOfSize: 1.
	gEmbeddings := Dictionary new.
	mEmbeddings := Dictionary new.
	vEmbeddings := Dictionary new
]

{ #category : 'training' }
CooNeuralMLP >> releaseOptimizer [
	"The gradients and the moments of Adam are only needed while training."

	gw1 := mw1 := vw1 := gb1 := mb1 := vb1 := gw2 := mw2 := vw2 := gb2 := mb2 := vb2 := nil.
	gEmbeddings := mEmbeddings := vEmbeddings := nil
]

{ #category : 'accessing' }
CooNeuralMLP >> scales [

	^ scales
]

{ #category : 'scoring' }
CooNeuralMLP >> scoreOf: aCandidate context: aContextEmbedding [

	^ self scoreOfHidden: (self hiddenOf: (self inputOf: aCandidate context: aContextEmbedding) first)
]

{ #category : 'scoring' }
CooNeuralMLP >> scoreOfHidden: aHidden [

	| score |
	score := b2 first.
	1 to: hiddenSize do: [ :k | score := score + ((w2 at: k) * (aHidden at: k)) ].
	^ score
]

{ #category : 'scoring' }
CooNeuralMLP >> scoresOf: aQuery [

	| contextEmbedding |
	contextEmbedding := self embeddingOf: aQuery contextIds.
	^ aQuery candidates collect: [ :candidate | self scoreOf: candidate context: contextEmbedding ]
]

{ #category : 'initialization' }
CooNeuralMLP >> setDenseSize: aDenseSize fetcherNames: aCollection hiddenSize: aHiddenSize embeddingSize: anEmbeddingSize buckets: aNumberOfBuckets [

	denseSize := aDenseSize.
	fetcherNames := (aCollection asArray collect: [ :each | each asString ]) sort.
	fetcherIndexes := Dictionary new.
	fetcherNames withIndexDo: [ :name :index | fetcherIndexes at: name put: index ].
	hiddenSize := aHiddenSize.
	embeddingSize := anEmbeddingSize.
	buckets := aNumberOfBuckets
]

{ #category : 'private' }
CooNeuralMLP >> zeroGradients [

	gw1 do: [ :row | row atAllPut: 0.0 ].
	gb1 atAllPut: 0.0.
	gw2 atAllPut: 0.0.
	gb2 atAllPut: 0.0.
	gEmbeddings := Dictionary new
]

{ #category : 'private' }
CooNeuralMLP >> zerosOfSize: anInteger [

	^ Array new: anInteger withAll: 0.0
]
