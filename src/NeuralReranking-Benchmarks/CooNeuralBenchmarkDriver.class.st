"
I do the measured part of one completion request for one benchmark (CooNeuralBenchmarksMessage or
CooNeuralBenchmarksVariables), so both kinds share the same code:

1. the token of the call site is replaced by the prefix,
2. the time (microseconds) and the allocated bytes (VM parameter 34) are measured around building the
   completion and fetching the ten first candidates, i.e. including the re-ranking when there is one,
3. the token is put back, and the rank of the expected token is given to the benchmark (its usual
   accuracy, MRR, time and memory tables) and to my CooNeuralBenchmarkResult, and written to the CSV
   stream if any.
"
Class {
	#name : 'CooNeuralBenchmarkDriver',
	#superclass : 'Object',
	#instVars : [
		'task',
		'configuration',
		'reranker',
		'result',
		'packageName',
		'csvStream'
	],
	#category : 'NeuralReranking-Benchmarks-Core',
	#package : 'NeuralReranking-Benchmarks',
	#tag : 'Core'
}

{ #category : 'csv' }
CooNeuralBenchmarkDriver class >> csvHeader [

	^ 'kind,configuration,package,class,method,target,prefix,rank,poolRank,microseconds,rerankMicroseconds,allocatedBytes,failed'
]

{ #category : 'csv' }
CooNeuralBenchmarkDriver class >> quoted: aString [

	^ '"' , (aString asString copyReplaceAll: '"' with: '""') , '"'
]

{ #category : 'measuring' }
CooNeuralBenchmarkDriver >> allocatedBytes [

	^ Smalltalk vm parameterAt: 34
]

{ #category : 'measuring' }
CooNeuralBenchmarkDriver >> bench: aBenchmark node: aNode target: aToken prefixSize: aSize position: aPosition [

	| prefix allocated start elapsed completion candidates rank failed |
	prefix := aToken copyFrom: 1 to: aSize.
	reranker ifNotNil: [ reranker resetLast ].
	failed := false.
	task setPrefix: prefix on: aNode.
	[
	[
	allocated := self allocatedBytes.
	start := Time microsecondClockValue.
	completion := aBenchmark buildCompletionFor: aNode atPosition: aPosition.
	candidates := aBenchmark fetchTopCandidatesFrom: completion usingPrefix: prefix.
	elapsed := Time microsecondClockValue - start.
	allocated := self allocatedBytes - allocated ]
		on: Error
		do: [ :error |
			failed := true.
			candidates := #(  ).
			elapsed := Time microsecondClockValue - start.
			allocated := 0 ] ] ensure: [ task restore: aToken on: aNode ].
	rank := task rankOf: aToken in: candidates.
	aBenchmark trackCompletionResultsFor: aToken atIndex: rank withPrefix: prefix.
	aBenchmark logTime: elapsed / 1000.0 forPrefix: aSize.
	aBenchmark logMemory: allocated forPrefix: aSize.
	result
		addRank: rank
		prefixSize: aSize
		poolRank: (reranker ifNil: [ -1 ] ifNotNil: [ task rankOf: aToken in: reranker lastPool ])
		microseconds: elapsed
		rerankMicroseconds: (reranker ifNil: [ 0 ] ifNotNil: [ reranker lastMicroseconds ])
		allocatedBytes: allocated
		failed: failed.
	csvStream ifNotNil: [ self writeCsvLineFor: aNode target: aToken prefixSize: aSize failed: failed ]
]

{ #category : 'measuring' }
CooNeuralBenchmarkDriver >> benchAllPrefixesOf: aNode position: aPosition for: aBenchmark [

	| target |
	target := task targetOf: aNode.
	2 to: (task maxPrefixSizeFor: target) do: [ :size |
		self
			bench: aBenchmark
			node: aNode
			target: target
			prefixSize: size
			position: aPosition ]
]

{ #category : 'accessing' }
CooNeuralBenchmarkDriver >> configuration [

	^ configuration
]

{ #category : 'accessing' }
CooNeuralBenchmarkDriver >> configuration: aConfiguration [

	configuration := aConfiguration
]

{ #category : 'accessing' }
CooNeuralBenchmarkDriver >> csvStream: aWriteStream [

	csvStream := aWriteStream
]

{ #category : 'accessing' }
CooNeuralBenchmarkDriver >> packageName: aString [

	packageName := aString asString.
	result addPackageName: packageName
]

{ #category : 'accessing' }
CooNeuralBenchmarkDriver >> reranker [

	^ reranker
]

{ #category : 'accessing' }
CooNeuralBenchmarkDriver >> reranker: aRerankerOrNil [

	reranker := aRerankerOrNil
]

{ #category : 'accessing' }
CooNeuralBenchmarkDriver >> result [

	^ result
]

{ #category : 'accessing' }
CooNeuralBenchmarkDriver >> result: aBenchmarkResult [

	result := aBenchmarkResult
]

{ #category : 'accessing' }
CooNeuralBenchmarkDriver >> task [

	^ task
]

{ #category : 'accessing' }
CooNeuralBenchmarkDriver >> task: aTask [

	task := aTask
]

{ #category : 'csv' }
CooNeuralBenchmarkDriver >> writeCsvLineFor: aNode target: aToken prefixSize: aSize failed: aBoolean [

	| methodNode |
	methodNode := aNode methodNode.
	csvStream
		nextPutAll: task kind;
		nextPut: $,;
		nextPutAll: configuration key;
		nextPut: $,;
		nextPutAll: (self class quoted: packageName asString);
		nextPut: $,;
		nextPutAll: (self class quoted: (methodNode methodClass ifNil: [ '' ] ifNotNil: [ :class | class name ]));
		nextPut: $,;
		nextPutAll: (self class quoted: methodNode selector);
		nextPut: $,;
		nextPutAll: (self class quoted: aToken);
		nextPut: $,;
		print: aSize;
		nextPut: $,;
		print: result ranks last;
		nextPut: $,;
		print: result poolRanksLast;
		nextPut: $,;
		print: result microseconds last;
		nextPut: $,;
		print: result rerankMicroseconds last;
		nextPut: $,;
		print: result allocatedBytes last;
		nextPut: $,;
		nextPutAll: (aBoolean
				 ifTrue: [ '1' ]
				 ifFalse: [ '0' ]);
		lf
]
