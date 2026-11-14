"
I hold what the feature extractors compute once per completion request and share between its candidates:
the index of the package of the method being written, the key of that method, the class, the receiver
of the message (for message completion) and the hashed context sub-words.
"
Class {
	#name : 'CooNeuralContext',
	#superclass : 'Object',
	#instVars : [
		'packageIndex',
		'methodKey',
		'completionClass',
		'receiverKey',
		'receiverKind',
		'ids',
		'leaveOneOut',
		'classWords',
		'packageRoot',
		'isTestContext'
	],
	#category : 'NeuralReranking-Core-Features',
	#package : 'NeuralReranking-Core',
	#tag : 'Features'
}

{ #category : 'accessing' }
CooNeuralContext >> classWords [

	^ classWords
]

{ #category : 'accessing' }
CooNeuralContext >> classWords: aCollection [

	classWords := aCollection
]

{ #category : 'accessing' }
CooNeuralContext >> completionClass [

	^ completionClass
]

{ #category : 'accessing' }
CooNeuralContext >> completionClass: aClass [

	completionClass := aClass
]

{ #category : 'accessing' }
CooNeuralContext >> ids [

	^ ids
]

{ #category : 'accessing' }
CooNeuralContext >> ids: anArray [

	ids := anArray
]

{ #category : 'accessing' }
CooNeuralContext >> isTestContext [

	^ isTestContext ifNil: [ false ]
]

{ #category : 'accessing' }
CooNeuralContext >> isTestContext: aBoolean [

	isTestContext := aBoolean
]

{ #category : 'accessing' }
CooNeuralContext >> leaveOneOut [

	^ leaveOneOut ifNil: [ false ]
]

{ #category : 'accessing' }
CooNeuralContext >> leaveOneOut: aBoolean [

	leaveOneOut := aBoolean
]

{ #category : 'accessing' }
CooNeuralContext >> methodKey [

	^ methodKey
]

{ #category : 'accessing' }
CooNeuralContext >> methodKey: aString [

	methodKey := aString
]

{ #category : 'accessing' }
CooNeuralContext >> packageIndex [

	^ packageIndex
]

{ #category : 'accessing' }
CooNeuralContext >> packageIndex: aPackageIndex [

	packageIndex := aPackageIndex
]

{ #category : 'accessing' }
CooNeuralContext >> packageRoot [

	^ packageRoot
]

{ #category : 'accessing' }
CooNeuralContext >> packageRoot: aString [

	packageRoot := aString
]

{ #category : 'accessing' }
CooNeuralContext >> receiverKey [

	^ receiverKey
]

{ #category : 'accessing' }
CooNeuralContext >> receiverKey: aString [

	receiverKey := aString
]

{ #category : 'accessing' }
CooNeuralContext >> receiverKind [

	^ receiverKind
]

{ #category : 'accessing' }
CooNeuralContext >> receiverKind: aSymbol [

	receiverKind := aSymbol
]
