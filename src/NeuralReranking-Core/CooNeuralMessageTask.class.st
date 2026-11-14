"
Message completion, as in CooStaticBenchmarksMessage: every message send whose selector has at least two
characters is a call site; the selector is replaced by its prefixes of 2 to 8 characters.
"
Class {
	#name : 'CooNeuralMessageTask',
	#superclass : 'CooNeuralTask',
	#category : 'NeuralReranking-Core-Tasks',
	#package : 'NeuralReranking-Core',
	#tag : 'Tasks'
}

{ #category : 'completion' }
CooNeuralMessageTask >> contextFor: aNode position: aPosition [

	^ CoBenchmarkContext new
		  callsite: aNode;
		  position: aPosition;
		  yourself
]

{ #category : 'testing' }
CooNeuralMessageTask >> isCallsite: aNode [

	^ aNode isMessage and: [ aNode selector size >= 2 ]
]

{ #category : 'accessing' }
CooNeuralMessageTask >> kind [

	^ #message
]

{ #category : 'completion' }
CooNeuralMessageTask >> positionOf: aNode [

	^ aNode keywordsIntervals first
]

{ #category : 'call sites' }
CooNeuralMessageTask >> restore: aSelector on: aNode [

	aNode selectorNode value: aSelector
]

{ #category : 'call sites' }
CooNeuralMessageTask >> setPrefix: aPrefix on: aNode [

	aNode selectorNode value: aPrefix
]

{ #category : 'call sites' }
CooNeuralMessageTask >> targetOf: aNode [

	^ aNode selector
]
