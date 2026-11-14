"
I am one completion request seen by the re-ranker: the candidates proposed by the heuristics, in their
original order (rank 1 first), the hashed sub-words of the context (receiver, class, method) and, in a
dataset, the index of the expected token among the candidates (targetIndex).
"
Class {
	#name : 'CooNeuralQuery',
	#superclass : 'Object',
	#instVars : [
		'candidates',
		'contextIds',
		'targetIndex',
		'prefixSize'
	],
	#category : 'NeuralReranking-Core-Features',
	#package : 'NeuralReranking-Core',
	#tag : 'Features'
}

{ #category : 'accessing' }
CooNeuralQuery >> candidates [

	^ candidates
]

{ #category : 'accessing' }
CooNeuralQuery >> candidates: anArray [

	candidates := anArray
]

{ #category : 'accessing' }
CooNeuralQuery >> contextIds [

	^ contextIds
]

{ #category : 'accessing' }
CooNeuralQuery >> contextIds: anArray [

	contextIds := anArray
]

{ #category : 'accessing' }
CooNeuralQuery >> prefixSize [

	^ prefixSize
]

{ #category : 'accessing' }
CooNeuralQuery >> prefixSize: anInteger [

	prefixSize := anInteger
]

{ #category : 'accessing' }
CooNeuralQuery >> size [

	^ candidates size
]

{ #category : 'accessing' }
CooNeuralQuery >> targetIndex [

	^ targetIndex ifNil: [ 0 ]
]

{ #category : 'accessing' }
CooNeuralQuery >> targetIndex: anInteger [

	targetIndex := anInteger
]
