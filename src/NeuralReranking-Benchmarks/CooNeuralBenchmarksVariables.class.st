"
I am CooStaticBenchmarksVariables (HeuristicCompletion-Benchmarks) with the measures of
CooNeuralBenchmarkDriver, as CooNeuralBenchmarksMessage is for messages.
"
Class {
	#name : 'CooNeuralBenchmarksVariables',
	#superclass : 'CooStaticBenchmarksVariables',
	#instVars : [
		'driver',
		'package',
		'callsitesPerPackage',
		'seed'
	],
	#category : 'NeuralReranking-Benchmarks-Core',
	#package : 'NeuralReranking-Benchmarks',
	#tag : 'Core'
}

{ #category : 'benchmarks' }
CooNeuralBenchmarksVariables >> benchCallsite: aVariableNode atPosition: aPosition [

	driver benchAllPrefixesOf: aVariableNode position: aPosition for: self
]

{ #category : 'accessing' }
CooNeuralBenchmarksVariables >> callsitesPerPackage: anIntegerOrNil [

	callsitesPerPackage := anIntegerOrNil
]

{ #category : 'accessing' }
CooNeuralBenchmarksVariables >> driver [

	^ driver
]

{ #category : 'accessing' }
CooNeuralBenchmarksVariables >> driver: aDriver [

	driver := aDriver
]

{ #category : 'benchmarks' }
CooNeuralBenchmarksVariables >> findCompletionIndexFor: aName inCandidates: candidates [

	^ driver task rankOf: aName in: candidates
]

{ #category : 'accessing' }
CooNeuralBenchmarksVariables >> package: aPackage [

	package := aPackage.
	scope := CoBenchmarkPackage on: aPackage
]

{ #category : 'accessing' }
CooNeuralBenchmarksVariables >> result [

	^ driver result
]

{ #category : 'running' }
CooNeuralBenchmarksVariables >> run [
	"Benchmark the call sites of my package only (see CooNeuralBenchmarkRunner to compare configurations)."

	CooNeuralBenchmarkRunner new
		runAlone: self
		package: package
		callsitesPerPackage: callsitesPerPackage
		seed: (seed ifNil: [ 42 ])
]

{ #category : 'accessing' }
CooNeuralBenchmarksVariables >> seed: anInteger [

	seed := anInteger
]
