"
Variable completion, as in CooStaticBenchmarksVariables: every capitalized variable (class names and
other globals) of at least two characters is a call site; its name is replaced by its prefixes of
2 to 8 characters.
"
Class {
	#name : 'CooNeuralVariableTask',
	#superclass : 'CooNeuralTask',
	#category : 'NeuralReranking-Core-Tasks',
	#package : 'NeuralReranking-Core',
	#tag : 'Tasks'
}

{ #category : 'completion' }
CooNeuralVariableTask >> contextFor: aNode position: aPosition [

	^ CoBenchmarkVariableContext new
		  callsite: aNode;
		  position: aPosition;
		  yourself
]

{ #category : 'testing' }
CooNeuralVariableTask >> isCallsite: aNode [

	^ aNode isVariable and: [ aNode name size >= 2 and: [ aNode name first isUppercase ] ]
]

{ #category : 'accessing' }
CooNeuralVariableTask >> kind [

	^ #variable
]

{ #category : 'completion' }
CooNeuralVariableTask >> positionOf: aNode [

	^ aNode start
]

{ #category : 'call sites' }
CooNeuralVariableTask >> restore: aName on: aNode [

	aNode name: aName
]

{ #category : 'call sites' }
CooNeuralVariableTask >> setPrefix: aPrefix on: aNode [

	aNode name: aPrefix
]

{ #category : 'call sites' }
CooNeuralVariableTask >> targetOf: aNode [

	^ aNode name
]
