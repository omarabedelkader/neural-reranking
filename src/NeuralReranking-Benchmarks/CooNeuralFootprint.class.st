"
I measure the memory held by an object: the sum of the sizes in memory of all the objects it reaches,
each counted once. Objects shared with the rest of the image are not counted: immediates, symbols,
classes, methods and packages.

    CooNeuralFootprint bytesOf: aReranker model.
"
Class {
	#name : 'CooNeuralFootprint',
	#superclass : 'Object',
	#category : 'NeuralReranking-Benchmarks-Core',
	#package : 'NeuralReranking-Benchmarks',
	#tag : 'Core'
}

{ #category : 'measuring' }
CooNeuralFootprint class >> bytesOf: anObject [

	| visited stack total |
	visited := IdentitySet new.
	stack := OrderedCollection with: anObject.
	total := 0.
	[ stack isEmpty ] whileFalse: [
		| object class |
		object := stack removeLast.
		((self isShared: object) or: [ visited includes: object ]) ifFalse: [
			visited add: object.
			total := total + object sizeInMemory.
			class := object class.
			1 to: class instSize do: [ :index | stack addLast: (object instVarAt: index) ].
			(class isVariable and: [ class isPointers ]) ifTrue: [
				1 to: object basicSize do: [ :index | stack addLast: (object basicAt: index) ] ] ] ].
	^ total
]

{ #category : 'testing' }
CooNeuralFootprint class >> isShared: anObject [

	anObject ifNil: [ ^ true ].
	anObject class isImmediateClass ifTrue: [ ^ true ].
	(anObject == true or: [ anObject == false ]) ifTrue: [ ^ true ].
	anObject isSymbol ifTrue: [ ^ true ].
	anObject isBehavior ifTrue: [ ^ true ].
	(anObject isKindOf: CompiledCode) ifTrue: [ ^ true ].
	(anObject isKindOf: Package) ifTrue: [ ^ true ].
	^ false
]
