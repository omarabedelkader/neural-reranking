"
I wrap the CoResultSet built by the heuristics. When asked for the first n candidates, I fetch the first
poolSize (at least n) candidates of the wrapped result set for the current filter, re-rank them with the
CooNeuralReranker and answer the first n of the new order.

Everything else (filters, narrowing, ...) is the wrapped result set.
"
Class {
	#name : 'CooNeuralRerankedResultSet',
	#superclass : 'Object',
	#instVars : [
		'resultSet',
		'reranker',
		'node',
		'completionClass'
	],
	#category : 'NeuralReranking-Core-Reranking',
	#package : 'NeuralReranking-Core',
	#tag : 'Reranking'
}

{ #category : 'instance creation' }
CooNeuralRerankedResultSet class >> on: aResultSet reranker: aReranker node: aNode completionClass: aClass [

	^ self new
		  setResultSet: aResultSet
		  reranker: aReranker
		  node: aNode
		  completionClass: aClass
]

{ #category : 'delegating' }
CooNeuralRerankedResultSet >> completionToken [

	^ resultSet completionToken
]

{ #category : 'reflective operations' }
CooNeuralRerankedResultSet >> doesNotUnderstand: aMessage [

	^ aMessage sendTo: resultSet
]

{ #category : 'delegating' }
CooNeuralRerankedResultSet >> fetcher [

	^ resultSet fetcher
]

{ #category : 'delegating' }
CooNeuralRerankedResultSet >> filter [

	^ resultSet filter
]

{ #category : 'accessing' }
CooNeuralRerankedResultSet >> first [

	| first |
	first := self first: 1.
	^ first isEmpty
		  ifTrue: [ nil ]
		  ifFalse: [ first first ]
]

{ #category : 'accessing' }
CooNeuralRerankedResultSet >> first: anInteger [

	| pool reranked |
	pool := resultSet first: (reranker poolSize max: anInteger).
	reranked := reranker
		            rerank: pool
		            prefix: self prefix
		            node: node
		            completionClass: completionClass.
	^ reranked size > anInteger
		  ifTrue: [ reranked first: anInteger ]
		  ifFalse: [ reranked ]
]

{ #category : 'delegating' }
CooNeuralRerankedResultSet >> hasMoreElements [

	^ resultSet hasMoreElements
]

{ #category : 'delegating' }
CooNeuralRerankedResultSet >> notEmpty [

	^ resultSet notEmpty
]

{ #category : 'accessing' }
CooNeuralRerankedResultSet >> prefix [

	^ [ resultSet filter completionString ]
		  on: Error
		  do: [ resultSet completionToken ]
]

{ #category : 'delegating' }
CooNeuralRerankedResultSet >> replaceFilterWith: aFilter [

	resultSet replaceFilterWith: aFilter
]

{ #category : 'delegating' }
CooNeuralRerankedResultSet >> resetFilter [

	resultSet resetFilter
]

{ #category : 'accessing' }
CooNeuralRerankedResultSet >> resultSet [

	^ resultSet
]

{ #category : 'initialization' }
CooNeuralRerankedResultSet >> setResultSet: aResultSet reranker: aReranker node: aNode completionClass: aClass [

	resultSet := aResultSet.
	reranker := aReranker.
	node := aNode.
	completionClass := aClass
]
