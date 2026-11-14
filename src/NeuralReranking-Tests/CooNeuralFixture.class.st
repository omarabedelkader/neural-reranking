"
I am a fixture of the tests: the selectors I send are known, so the counts of the package index can be checked.
"
Class {
	#name : 'CooNeuralFixture',
	#superclass : 'Object',
	#category : 'NeuralReranking-Tests',
	#package : 'NeuralReranking-Tests'
}

{ #category : 'fixture' }
CooNeuralFixture >> alpha [

	^ self cooNeuralUniqueSelector
]

{ #category : 'fixture' }
CooNeuralFixture >> beta [

	^ self cooNeuralSharedSelector
]

{ #category : 'fixture' }
CooNeuralFixture >> cooNeuralSharedSelector [

	^ 1
]

{ #category : 'fixture' }
CooNeuralFixture >> cooNeuralUniqueSelector [

	^ 2
]

{ #category : 'fixture' }
CooNeuralFixture >> gamma [

	^ self cooNeuralSharedSelector + OrderedCollection new size
]
