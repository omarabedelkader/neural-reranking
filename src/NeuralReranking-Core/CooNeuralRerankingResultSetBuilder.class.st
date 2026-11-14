"
I decorate a Complishon result set builder (e.g. a CoASTHeuristicsResultSetBuilder configured with some
heuristics) with a CooNeuralReranker: the completion I build answers the first candidates of the
decorated builder re-ranked by the network (see CooNeuralRerankedResultSet).

Since I understand #node:, #completionContext: and #buildCompletion, I can be given to any benchmark of
HeuristicCompletion-Benchmarks in place of the builder I decorate:

    CooStaticBenchmarksMessage new
        scope: (CoBenchmarkPackage on: aPackage);
        builder: (CooNeuralRerankingResultSetBuilder on: aBuilder reranker: aReranker);
        run.
"
Class {
	#name : 'CooNeuralRerankingResultSetBuilder',
	#superclass : 'CoResultSetBuilder',
	#instVars : [
		'decorated',
		'reranker',
		'node'
	],
	#category : 'NeuralReranking-Core-Reranking',
	#package : 'NeuralReranking-Core',
	#tag : 'Reranking'
}

{ #category : 'instance creation' }
CooNeuralRerankingResultSetBuilder class >> on: aResultSetBuilder reranker: aReranker [

	^ self new
		  decorated: aResultSetBuilder;
		  reranker: aReranker;
		  yourself
]

{ #category : 'building' }
CooNeuralRerankingResultSetBuilder >> buildCompletion [

	^ CooNeuralRerankedResultSet
		  on: decorated buildCompletion
		  reranker: reranker
		  node: node
		  completionClass: (completionContext ifNotNil: [ :context | context completionClass ])
]

{ #category : 'accessing' }
CooNeuralRerankingResultSetBuilder >> completionContext: aCompletionContext [

	super completionContext: aCompletionContext.
	decorated completionContext: aCompletionContext
]

{ #category : 'accessing' }
CooNeuralRerankingResultSetBuilder >> decorated [

	^ decorated
]

{ #category : 'accessing' }
CooNeuralRerankingResultSetBuilder >> decorated: aResultSetBuilder [

	decorated := aResultSetBuilder
]

{ #category : 'initialization' }
CooNeuralRerankingResultSetBuilder >> initializeOnContext: aCompletionContext [

	super initializeOnContext: aCompletionContext.
	decorated initializeOnContext: aCompletionContext
]

{ #category : 'accessing' }
CooNeuralRerankingResultSetBuilder >> node: aNode [

	node := aNode.
	decorated node: aNode
]

{ #category : 'printing' }
CooNeuralRerankingResultSetBuilder >> printOn: aStream [

	aStream
		print: decorated;
		nextPutAll: ' + ';
		print: reranker
]

{ #category : 'accessing' }
CooNeuralRerankingResultSetBuilder >> reranker [

	^ reranker
]

{ #category : 'accessing' }
CooNeuralRerankingResultSetBuilder >> reranker: aReranker [

	reranker := aReranker
]
