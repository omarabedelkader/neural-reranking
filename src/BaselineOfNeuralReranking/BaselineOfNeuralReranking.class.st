"
I load the neural re-ranker of code completion candidates and its benchmarks.

Groups:
- 'Core': features, the small neural network and the re-ranker (usable on top of any Complishon builder);
- 'Training': package split, dataset extraction and training;
- 'Benchmarks': the six configurations (Baseline, Semantics, Dependency, each alone and re-ranked) run with
  the HeuristicCompletion-Benchmarks framework, with time and memory measurements;
- 'Tests'.
"
Class {
	#name : 'BaselineOfNeuralReranking',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfNeuralReranking',
	#package : 'BaselineOfNeuralReranking'
}

{ #category : 'baselines' }
BaselineOfNeuralReranking >> baseline: spec [

	<baseline>
	spec for: #common do: [
		spec
			baseline: 'ExtendedHeuristicCompletionBenchmarks'
			with: [ spec repository: 'github://omarabedelkader/HeuristicCompletion-Benchmarks:main/src' ].

		spec
			package: 'NeuralReranking-Core';
			package: 'NeuralReranking-Training'
			with: [ spec requires: #( 'NeuralReranking-Core' ) ];
			package: 'NeuralReranking-Benchmarks'
			with: [ spec requires: #( 'NeuralReranking-Training' 'ExtendedHeuristicCompletionBenchmarks' ) ];
			package: 'NeuralReranking-Tests'
			with: [ spec requires: #( 'NeuralReranking-Benchmarks' ) ].

		spec
			group: 'Core' with: #( 'NeuralReranking-Core' );
			group: 'Training' with: #( 'NeuralReranking-Training' );
			group: 'Benchmarks' with: #( 'NeuralReranking-Benchmarks' );
			group: 'Tests' with: #( 'NeuralReranking-Tests' );
			group: 'default' with: #( 'Benchmarks' 'Tests' ) ]
]
