"
I am CoDependencyMessageHeuristics with a fetcher that tolerates the packages whose dependencies cannot
be computed (CooNeuralDependencySelectorFetcher).
"
Class {
	#name : 'CooNeuralDependencyMessageHeuristic',
	#superclass : 'CoDependencyMessageHeuristics',
	#category : 'NeuralReranking-Core-Heuristics',
	#package : 'NeuralReranking-Core',
	#tag : 'Heuristics'
}

{ #category : 'requests' }
CooNeuralDependencyMessageHeuristic >> buildFetcherFor: aNode inContext: completionContext [

	^ CooNeuralDependencySelectorFetcher new
		  completionClass: completionContext completionClass;
		  astNode: aNode;
		  yourself
]
