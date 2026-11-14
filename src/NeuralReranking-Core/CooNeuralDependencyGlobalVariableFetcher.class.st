"
I am CoDependencyGlobalVariableFetcher, except that I skip the dependencies that are not loaded and give
no dependencies to a package whose dependencies cannot be computed (the original sends #definedClasses
to nil and stops the benchmark). Same as in HeuristicCompletion-History.
"
Class {
	#name : 'CooNeuralDependencyGlobalVariableFetcher',
	#superclass : 'CoDependencyGlobalVariableFetcher',
	#category : 'NeuralReranking-Core-Heuristics',
	#package : 'NeuralReranking-Core',
	#tag : 'Heuristics'
}

{ #category : 'accessing' }
CooNeuralDependencyGlobalVariableFetcher >> dependenciesOf: aPackageName [

	^ [ super dependenciesOf: aPackageName ]
		  on: Error
		  do: [ #(  ) ]
]

{ #category : 'enumerating' }
CooNeuralDependencyGlobalVariableFetcher >> entriesDo: aBlock [

	| dependentClassNames |
	completionClass ifNil: [ ^ self ].
	self packageLocalClasses: aBlock.
	dependentClassNames := SortedCollection sortUsing: [ :a :b | a <= b ].
	(self dependenciesOf: package name) do: [ :packageName |
		(organizer packageNamed: packageName ifAbsent: [ nil ]) ifNotNil: [ :dependency |
			dependentClassNames addAll: (dependency definedClasses collect: [ :each | each name ]) ] ].
	dependentClassNames do: [ :className |
		aBlock value: ((CoGlobalEntry contents: className node: nil)
				 fetcherName: self class name;
				 yourself) ]
]
