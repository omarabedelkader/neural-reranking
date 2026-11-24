Class {
	#name : 'CooNeuralOverheadReportTest',
	#superclass : 'TestCase',
	#category : 'NeuralReranking-Tests',
	#package : 'NeuralReranking-Tests'
}

{ #category : 'helpers' }
CooNeuralOverheadReportTest >> directory [
	"An output directory in memory: two requests (one of them twice), the heuristics and their re-ranking."

	| root results |
	root := FileSystem memory root.
	results := Dictionary new
		           at: #heapBytes put: (Dictionary new
				            at: #message put: #( 104857600 2147483648 );
				            yourself);
		           at: #results put: { (#message -> {
						             (Dictionary new
							              at: #key put: 'baseline';
							              at: #configuration put: 'Baseline';
							              yourself).
						             (Dictionary new
							              at: #key put: #'baseline-nr';
							              at: #configuration put: 'Baseline + Re-ranking';
							              at: #packages put: #( 'P' );
							              at: #modelBytes put: 1048576;
							              at: #statisticsBytes put: 2097152;
							              at: #meanIndexBytes put: 524288;
							              at: #meanIndexMilliseconds put: 3.0;
							              at: #modelParameters put: 100;
							              yourself) }) };
		           yourself.
	(root / 'results.ston') writeStreamDo: [ :stream | stream nextPutAll: (STON toString: results) ].
	(root / 'benchmark') ensureCreateDirectory.
	(root / 'benchmark' / 'requests-message.csv') writeStreamDo: [ :stream |
		stream
			nextPutAll: CooNeuralBenchmarkDriver csvHeader; lf;
			nextPutAll: 'message,baseline,"P","C","m","a,b",2,1,1,1000,0,100,0'; lf;
			nextPutAll: 'message,baseline-nr,"P","C","m","a,b",2,1,1,1500,300,250,0'; lf;
			nextPutAll: 'message,baseline,"P","C","m","x",2,1,1,2000,0,100,0'; lf;
			nextPutAll: 'message,baseline-nr,"P","C","m","x",2,1,1,2100,200,150,0'; lf;
			nextPutAll: 'message,baseline,"P","C","m","x",2,1,1,3000,0,100,0'; lf;
			nextPutAll: 'message,baseline-nr,"P","C","m","x",2,1,1,3400,400,200,0'; lf ].
	^ root
]

{ #category : 'tests' }
CooNeuralOverheadReportTest >> testFieldsOfQuotedLine [

	self
		assert: (CooNeuralOverheadReport new fieldsOf: 'a,"b,c","say ""hi""",,1')
		equals: #( 'a' 'b,c' 'say "hi"' '' '1' )
]

{ #category : 'tests' }
CooNeuralOverheadReportTest >> testOverheadIsPairedRequestByRequest [

	| directory overhead |
	directory := self directory.
	overhead := (CooNeuralOverheadReport new
		             directory: directory;
		             overheads) first.
	self assert: (overhead at: #pairedRequests) equals: 3.
	self assert: (overhead at: #meanWithoutMicroseconds) equals: 2000.
	self assert: (overhead at: #meanWithMicroseconds) equals: 7000 / 3.
	"extras of 500, 100 and 400 microseconds"
	self assert: (overhead at: #meanExtraMicroseconds) equals: 1000 / 3.
	self assert: (overhead at: #medianExtraMicroseconds) equals: 400.
	self assert: (overhead at: #meanRerankMicroseconds) equals: 300.
	self assert: (overhead at: #meanExtraAllocatedBytes) equals: 100.
	self assert: (overhead at: #heldBytes) equals: 1048576 + 2097152 + 524288.
	CooNeuralOverheadReport writeIn: directory.
	self assert: ((directory / 'overhead.md') contents includesSubstring: '+0.33').
	self assert: ((directory / 'overhead.md') contents includesSubstring: '2.00 GB after').
	self assert: ((directory / 'overhead.tex') contents includesSubstring: '3.50')
]
