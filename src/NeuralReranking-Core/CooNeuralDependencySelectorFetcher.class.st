"
I am CoDependencySelectorFetcher, except that a package whose dependencies cannot be computed gets no
dependency candidates instead of stopping the benchmark (same as in HeuristicCompletion-History).
"
Class {
	#name : 'CooNeuralDependencySelectorFetcher',
	#superclass : 'CoDependencySelectorFetcher',
	#category : 'NeuralReranking-Core-Heuristics',
	#package : 'NeuralReranking-Core',
	#tag : 'Heuristics'
}

{ #category : 'accessing' }
CooNeuralDependencySelectorFetcher >> dependenciesOf: aPackageName [

	^ [ super dependenciesOf: aPackageName ]
		  on: Error
		  do: [ #(  ) ]
]
