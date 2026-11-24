"
I write the results of a CooNeuralExperiment in its output directory:

- split.md, split.ston                  the training, validation and test packages;
- summary.md                            all the tables (accuracy, time, memory, costs, training);
- summary.csv                           one line per kind of completion and configuration;
- summary.tex                           LaTeX tables;
- overhead.md, overhead.tex             the milliseconds and the MB the re-ranking adds (CooNeuralOverheadReport);
- prefix-mrr.csv                        MRR@10 per prefix size;
- packages.csv                          MRR@10 and mean time per test package;
- training/<kind>-<configuration>.csv   the validation curves of the training;
- benchmark/<kind>-<configuration>.txt  the text report of HeuristicCompletion-Benchmarks for every configuration;
- benchmark/requests-<kind>.csv         every request (written while benchmarking);
- results.ston                          everything above as data.
"
Class {
	#name : 'CooNeuralReport',
	#superclass : 'Object',
	#instVars : [
		'experiment'
	],
	#category : 'NeuralReranking-Benchmarks-Experiment',
	#package : 'NeuralReranking-Benchmarks',
	#tag : 'Experiment'
}

{ #category : 'accessing' }
CooNeuralReport >> baseResultOf: aResult in: someResults [

	^ someResults detect: [ :each | each configuration = aResult configuration baseConfiguration ]
]

{ #category : 'accessing' }
CooNeuralReport >> experiment: anExperiment [

	experiment := anExperiment
]

{ #category : 'formatting' }
CooNeuralReport >> format: aNumber [

	^ self format: aNumber places: 4
]

{ #category : 'formatting' }
CooNeuralReport >> format: aNumber places: anInteger [

	aNumber ifNil: [ ^ '' ].
	^ aNumber asFloat printShowingDecimalPlaces: anInteger
]

{ #category : 'formatting' }
CooNeuralReport >> kb: aByteCount [

	^ self format: (aByteCount ifNil: [ 0 ]) / 1024.0 places: 1
]

{ #category : 'formatting' }
CooNeuralReport >> kindTitle: aKind [

	^ aKind = #message
		  ifTrue: [ 'Message completion' ]
		  ifFalse: [ 'Variable (class name) completion' ]
]

{ #category : 'accessing' }
CooNeuralReport >> resultsOf: aKind [

	^ (experiment runners at: aKind ifAbsent: [ ^ #(  ) ]) results
]

{ #category : 'writing' }
CooNeuralReport >> write: aString to: aFileReference [

	aFileReference parent ensureCreateDirectory.
	aFileReference ensureDelete.
	aFileReference writeStreamDo: [ :stream | stream nextPutAll: aString ]
]

{ #category : 'writing' }
CooNeuralReport >> writeAll [

	self
		writeSplit;
		writeTraining;
		writeBenchmarkReports;
		writeSummaryCsv;
		writePrefixCsv;
		writePackagesCsv;
		writeLatex;
		writeSton;
		writeMarkdown.
	"from the files just written (results.ston, benchmark/requests-<kind>.csv)"
	CooNeuralOverheadReport writeIn: experiment outputDirectory
]

{ #category : 'writing' }
CooNeuralReport >> writeBenchmarkReports [
	"The text report of HeuristicCompletion-Benchmarks (accuracy, time, memory, MRR, NDCG, recall tables)."

	experiment runners keysAndValuesDo: [ :kind :runner |
		runner benchmarks do: [ :benchmark |
			self
				write: (([ benchmark textReport ]
						  on: Error
						  do: [ :error | 'No text report: ' , error messageText asString ]) withUnixLineEndings)
				to: experiment outputDirectory / 'benchmark' / (kind , '-' , benchmark driver configuration key , '.txt') ] ]
]

{ #category : 'writing' }
CooNeuralReport >> writeLatex [

	| string |
	string := String streamContents: [ :stream |
		          experiment kinds do: [ :kind |
			          | results |
			          results := self resultsOf: kind.
			          stream
				          nextPutAll: '% ';
				          nextPutAll: (self kindTitle: kind);
				          lf;
				          nextPutAll: '\begin{tabular}{lrrrrrrr}';
				          lf;
				          nextPutAll: '\hline';
				          lf;
				          nextPutAll:
					          'Configuration & MRR@10 & $\Delta$ MRR & R@1 & R@10 & Mean (ms) & p95 (ms) & Alloc. (KB) \\';
				          lf;
				          nextPutAll: '\hline';
				          lf.
			          results do: [ :result |
				          | summary |
				          summary := result asDictionary.
				          stream
					          nextPutAll: result configuration name;
					          nextPutAll: ' & ';
					          nextPutAll: (self format: (summary at: #mrr) places: 3);
					          nextPutAll: ' & ';
					          nextPutAll: (result configuration isReranked
							           ifTrue: [
								           self
									           format: ((result comparisonWith: (self baseResultOf: result in: results)) at: #deltaMrr)
									           places: 3 ]
							           ifFalse: [ '--' ]);
					          nextPutAll: ' & ';
					          nextPutAll: (self format: (summary at: #recall1) places: 3);
					          nextPutAll: ' & ';
					          nextPutAll: (self format: (summary at: #recall10) places: 3);
					          nextPutAll: ' & ';
					          nextPutAll: (self format: (summary at: #meanMicroseconds) / 1000.0 places: 2);
					          nextPutAll: ' & ';
					          nextPutAll: (self format: (summary at: #p95Microseconds) / 1000.0 places: 2);
					          nextPutAll: ' & ';
					          nextPutAll: (self kb: (summary at: #meanAllocatedBytes));
					          nextPutAll: ' \\';
					          lf ].
			          stream
				          nextPutAll: '\hline';
				          lf;
				          nextPutAll: '\end{tabular}';
				          lf;
				          lf ] ].
	self write: string to: experiment outputDirectory / 'summary.tex'
]

{ #category : 'writing' }
CooNeuralReport >> writeMarkdown [

	| string |
	string := String streamContents: [ :stream | self writeMarkdownOn: stream ].
	self write: string to: experiment outputDirectory / 'summary.md'.
	Stdio stdout
		lf;
		nextPutAll: string;
		lf;
		flush
]

{ #category : 'writing' }
CooNeuralReport >> writeMarkdownCostsOn: aStream [

	aStream
		nextPutAll: '## Cost of the re-rankers';
		lf;
		lf;
		nextPutAll:
			'| Kind | Re-ranker | Parameters | Network (KB) | Corpus statistics (KB) | Target in pool | Indexing a package (ms) | Package index (KB) |';
		lf;
		nextPutAll: '|---|---|---:|---:|---:|---:|---:|---:|';
		lf.
	experiment kinds do: [ :kind |
		(self resultsOf: kind) do: [ :result |
			result configuration isReranked ifTrue: [
				| summary |
				summary := result asDictionary.
				aStream
					nextPutAll: '| ';
					nextPutAll: kind;
					nextPutAll: ' | ';
					nextPutAll: result configuration name;
					nextPutAll: ' | ';
					print: (summary at: #modelParameters);
					nextPutAll: ' | ';
					nextPutAll: (self kb: (summary at: #modelBytes));
					nextPutAll: ' | ';
					nextPutAll: (self kb: (summary at: #statisticsBytes));
					nextPutAll: ' | ';
					nextPutAll: (self format: (summary at: #poolRecall) places: 3);
					nextPutAll: ' | ';
					nextPutAll: (self format: (summary at: #meanIndexMilliseconds) places: 1);
					nextPutAll: ' | ';
					nextPutAll: (self kb: (summary at: #meanIndexBytes));
					nextPutAll: ' |';
					lf ] ] ].
	aStream
		lf;
		nextPutAll:
			'*Target in pool*: how often the expected token is among the candidates given to the re-ranker (the best it can do). ';
		nextPutAll:
			'Indexing a package happens once per package, before its first completion, and is not in the completion times.';
		lf;
		lf
]

{ #category : 'writing' }
CooNeuralReport >> writeMarkdownKind: aKind on: aStream [

	| results |
	results := self resultsOf: aKind.
	results isEmpty ifTrue: [ ^ self ].
	aStream
		nextPutAll: '## ';
		nextPutAll: (self kindTitle: aKind);
		lf;
		lf;
		print: results first size;
		nextPutAll: ' requests (call site x prefix of 2 to 8 characters) per configuration, on ';
		print: results first packageNames size;
		nextPutAll: ' test packages.';
		lf;
		lf;
		nextPutAll:
			'| Configuration | MRR@10 | Delta MRR | Recall@1 | Recall@3 | Recall@10 | Wins / ties / losses | Mean time (us) | Median (us) | p95 (us) | Re-ranking (us) | Allocated (KB/request) |';
		lf;
		nextPutAll: '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|';
		lf.
	results do: [ :result |
		| summary comparison |
		summary := result asDictionary.
		comparison := result configuration isReranked ifTrue: [
			              result comparisonWith: (self baseResultOf: result in: results) ].
		aStream
			nextPutAll: '| ';
			nextPutAll: result configuration name;
			nextPutAll: ' | ';
			nextPutAll: (self format: (summary at: #mrr));
			nextPutAll: ' | ';
			nextPutAll: (comparison
					 ifNil: [ '' ]
					 ifNotNil: [ (self format: (comparison at: #deltaMrr)) ]);
			nextPutAll: ' | ';
			nextPutAll: (self format: (summary at: #recall1));
			nextPutAll: ' | ';
			nextPutAll: (self format: (summary at: #recall3));
			nextPutAll: ' | ';
			nextPutAll: (self format: (summary at: #recall10));
			nextPutAll: ' | ';
			nextPutAll: (comparison
					 ifNil: [ '' ]
					 ifNotNil: [
						 (comparison at: #wins) printString , ' / ' , (comparison at: #ties) printString , ' / '
						 , (comparison at: #losses) printString ]);
			nextPutAll: ' | ';
			nextPutAll: (self format: (summary at: #meanMicroseconds) places: 0);
			nextPutAll: ' | ';
			nextPutAll: (self format: (summary at: #medianMicroseconds) places: 0);
			nextPutAll: ' | ';
			nextPutAll: (self format: (summary at: #p95Microseconds) places: 0);
			nextPutAll: ' | ';
			nextPutAll: (self format: (summary at: #meanRerankMicroseconds) places: 0);
			nextPutAll: ' | ';
			nextPutAll: (self kb: (summary at: #meanAllocatedBytes));
			nextPutAll: ' |';
			lf ].
	(results anySatisfy: [ :result | result failures > 0 ]) ifTrue: [
		aStream
			lf;
			nextPutAll: 'Failed completions (counted as not found): '.
		results
			do: [ :result |
				aStream
					nextPutAll: result configuration name;
					nextPutAll: ' ';
					print: result failures ]
			separatedBy: [ aStream nextPutAll: ', ' ].
		aStream lf ].
	aStream lf
]

{ #category : 'writing' }
CooNeuralReport >> writeMarkdownOn: aStream [

	| split settings |
	split := experiment split.
	settings := experiment settings.
	aStream
		nextPutAll: '# Neural re-ranking of code completion';
		lf;
		lf;
		nextPutAll: '- Date: ';
		print: (experiment startTime ifNil: [ DateAndTime now ]);
		lf;
		nextPutAll: '- Image: ';
		nextPutAll: SystemVersion current printString;
		lf.
	(experiment startTime notNil and: [ experiment endTime notNil ]) ifTrue: [
		aStream
			nextPutAll: '- Duration: ';
			print: experiment endTime - experiment startTime;
			lf ].
	aStream
		nextPutAll: '- Packages (split by project, seed ';
		print: experiment seed;
		nextPutAll: '): ';
		print: split trainPackageNames size;
		nextPutAll: ' training, ';
		print: split validationPackageNames size;
		nextPutAll: ' validation, ';
		print: split testPackageNames size;
		nextPutAll: ' test (see split.md)';
		lf;
		nextPutAll: '- Re-ranker: the first ';
		print: (settings at: #poolSize);
		nextPutAll: ' candidates of the heuristics; network: ';
		print: (settings at: #hiddenSize);
		nextPutAll: ' hidden units, embeddings of ';
		print: (settings at: #embeddingSize);
		nextPutAll: ' in ';
		print: (settings at: #buckets);
		nextPutAll: ' hash buckets; at most ';
		print: (settings at: #epochs);
		nextPutAll: ' epochs (early stopping on validation MRR, patience ';
		print: (settings at: #patience);
		nextPutAll: ')';
		lf;
		nextPutAll: '- Time: building the completion, fetching and re-ranking the 10 first candidates (microseconds). ';
		nextPutAll: 'Memory: bytes allocated during that time (VM parameter 34).';
		lf;
		lf.
	experiment kinds do: [ :kind | self writeMarkdownKind: kind on: aStream ].
	self writeMarkdownPrefixesOn: aStream.
	self writeMarkdownCostsOn: aStream.
	self writeMarkdownTrainingOn: aStream
]

{ #category : 'writing' }
CooNeuralReport >> writeMarkdownPrefixesOn: aStream [

	aStream
		nextPutAll: '## MRR@10 per prefix size';
		lf;
		lf;
		nextPutAll: '| Kind | Configuration |'.
	(2 to: 8) do: [ :size |
		aStream
			nextPutAll: ' ';
			print: size;
			nextPutAll: ' |' ].
	aStream
		lf;
		nextPutAll: '|---|---|---:|---:|---:|---:|---:|---:|---:|';
		lf.
	experiment kinds do: [ :kind |
		(self resultsOf: kind) do: [ :result |
			aStream
				nextPutAll: '| ';
				nextPutAll: kind;
				nextPutAll: ' | ';
				nextPutAll: result configuration name;
				nextPutAll: ' |'.
			(2 to: 8) do: [ :size |
				aStream
					nextPutAll: ' ';
					nextPutAll: (self format: (result mrrForPrefixSize: size) places: 3);
					nextPutAll: ' |' ].
			aStream lf ] ].
	aStream lf
]

{ #category : 'writing' }
CooNeuralReport >> writeMarkdownTrainingOn: aStream [

	aStream
		nextPutAll: '## Training and validation';
		lf;
		lf;
		nextPutAll:
			'| Kind | Configuration | Training queries | Validation requests | Validation MRR@10, heuristics | Validation MRR@10, re-ranked | Best epoch | Training (s) | Extraction (s) |';
		lf;
		nextPutAll: '|---|---|---:|---:|---:|---:|---:|---:|---:|';
		lf.
	experiment kinds do: [ :kind |
		experiment baseNames do: [ :base |
			| summary validation |
			summary := (experiment rerankerFor: kind base: base) trainingSummary.
			validation := summary at: #validation ifAbsent: [ Dictionary new ].
			aStream
				nextPutAll: '| ';
				nextPutAll: kind;
				nextPutAll: ' | ';
				nextPutAll: (CooNeuralHeuristics labelOf: base);
				nextPutAll: ' | ';
				print: (summary at: #trainingQueries ifAbsent: [ 0 ]);
				nextPutAll: ' | ';
				print: (summary at: #validationRequests ifAbsent: [ 0 ]);
				nextPutAll: ' | ';
				nextPutAll: (self format: (validation at: #baseMrr ifAbsent: [ nil ]));
				nextPutAll: ' | ';
				nextPutAll: (self format: (validation at: #mrr ifAbsent: [ nil ]));
				nextPutAll: ' | ';
				print: (summary at: #bestEpoch ifAbsent: [ 0 ]);
				nextPutAll: ' | ';
				nextPutAll: (self format: (summary at: #trainingSeconds ifAbsent: [ nil ]) places: 1);
				nextPutAll: ' | ';
				nextPutAll: (self format: (summary at: #extractionSeconds ifAbsent: [ nil ]) places: 1);
				nextPutAll: ' |';
				lf ] ].
	aStream lf.
	experiment heapBytes isEmpty ifTrue: [ ^ self ].
	aStream
		nextPutAll: 'Heap of the image (MB) before / after benchmarking: '.
	experiment heapBytes associations
		do: [ :association |
			aStream
				nextPutAll: association key;
				nextPutAll: ' ';
				nextPutAll: (self format: association value first / 1048576.0 places: 1);
				nextPutAll: ' / ';
				nextPutAll: (self format: association value second / 1048576.0 places: 1) ]
		separatedBy: [ aStream nextPutAll: ', ' ].
	aStream
		lf;
		lf
]

{ #category : 'writing' }
CooNeuralReport >> writePackagesCsv [

	| string |
	string := String streamContents: [ :stream |
		          stream
			          nextPutAll: 'kind,configuration,package,requests,mrr10,meanMicroseconds';
			          lf.
		          experiment kinds do: [ :kind |
			          (self resultsOf: kind) do: [ :result |
				          result packageNames do: [ :name |
					          | measures |
					          measures := result measuresForPackage: name.
					          stream
						          nextPutAll: kind;
						          nextPut: $,;
						          nextPutAll: result configuration key;
						          nextPut: $,;
						          nextPutAll: name;
						          nextPut: $,;
						          print: (measures at: #requests);
						          nextPut: $,;
						          nextPutAll: (self format: (measures at: #mrr) places: 6);
						          nextPut: $,;
						          nextPutAll: (self format: (measures at: #meanMicroseconds) places: 1);
						          lf ] ] ] ].
	self write: string to: experiment outputDirectory / 'packages.csv'
]

{ #category : 'writing' }
CooNeuralReport >> writePrefixCsv [

	| string |
	string := String streamContents: [ :stream |
		          stream
			          nextPutAll: 'kind,configuration,prefix,mrr10';
			          lf.
		          experiment kinds do: [ :kind |
			          (self resultsOf: kind) do: [ :result |
				          result prefixSizesSeen do: [ :size |
					          stream
						          nextPutAll: kind;
						          nextPut: $,;
						          nextPutAll: result configuration key;
						          nextPut: $,;
						          print: size;
						          nextPut: $,;
						          nextPutAll: (self format: (result mrrForPrefixSize: size) places: 6);
						          lf ] ] ] ].
	self write: string to: experiment outputDirectory / 'prefix-mrr.csv'
]

{ #category : 'writing' }
CooNeuralReport >> writeSplit [

	| split string |
	split := experiment split.
	string := String streamContents: [ :stream |
		          {
			          ('Training' -> split trainPackageNames).
			          ('Validation' -> split validationPackageNames).
			          ('Test' -> split testPackageNames) } do: [ :association |
			          stream
				          nextPutAll: '## ';
				          nextPutAll: association key;
				          nextPutAll: ' packages (';
				          print: association value size;
				          nextPutAll: ')';
				          lf;
				          lf.
			          association value do: [ :name |
				          stream
					          nextPutAll: '- ';
					          nextPutAll: name;
					          lf ].
			          stream lf ] ].
	self write: string to: experiment outputDirectory / 'split.md'.
	self write: (STON toStringPretty: split asDictionary) to: experiment outputDirectory / 'split.ston'
]

{ #category : 'writing' }
CooNeuralReport >> writeSton [

	| dictionary |
	dictionary := Dictionary new.
	dictionary
		at: #settings put: experiment settings;
		at: #split put: experiment split asDictionary;
		at: #heapBytes put: experiment heapBytes;
		at: #results put: (experiment kinds collect: [ :kind |
					 kind -> ((self resultsOf: kind) collect: [ :result |
						   | summary |
						   summary := result asDictionary.
						   result configuration isReranked ifTrue: [
							   summary
								   at: #comparison
								   put: (result comparisonWith: (self baseResultOf: result in: (self resultsOf: kind))) ].
						   summary ]) asArray ]) asArray;
		at: #training put: (experiment kinds collect: [ :kind |
					 kind -> (experiment baseNames collect: [ :base |
						   | summary |
						   summary := (experiment rerankerFor: kind base: base) trainingSummary copy.
						   summary removeKey: #history ifAbsent: [  ].
						   base -> summary ]) asArray ]) asArray.
	self write: (STON toStringPretty: dictionary) to: experiment outputDirectory / 'results.ston'
]

{ #category : 'writing' }
CooNeuralReport >> writeSummaryCsv [

	| keys string |
	keys := #( #requests #failures #mrr #recall1 #recall3 #recall5 #recall10 #meanMicroseconds #medianMicroseconds
	           #p95Microseconds #p99Microseconds #meanRerankMicroseconds #p95RerankMicroseconds #meanAllocatedBytes
	           #medianAllocatedBytes #p95AllocatedBytes #poolRecall #meanIndexMilliseconds #meanIndexBytes #modelBytes
	           #statisticsBytes #modelParameters ).
	string := String streamContents: [ :stream |
		          stream nextPutAll: 'kind,configuration,reranked'.
		          keys do: [ :key |
			          stream
				          nextPut: $,;
				          nextPutAll: key ].
		          stream
			          nextPutAll: ',deltaMrr,wins,ties,losses';
			          lf.
		          experiment kinds do: [ :kind |
			          | results |
			          results := self resultsOf: kind.
			          results do: [ :result |
				          | summary |
				          summary := result asDictionary.
				          stream
					          nextPutAll: kind;
					          nextPut: $,;
					          nextPutAll: result configuration key;
					          nextPut: $,;
					          print: result configuration isReranked.
				          keys do: [ :key |
					          stream nextPut: $,.
					          (summary at: key ifAbsent: [ nil ]) ifNotNil: [ :value |
						          value isFloat
							          ifTrue: [ stream nextPutAll: (self format: value places: 6) ]
							          ifFalse: [ stream print: value ] ] ].
				          result configuration isReranked
					          ifTrue: [
						          | comparison |
						          comparison := result comparisonWith: (self baseResultOf: result in: results).
						          stream
							          nextPut: $,;
							          nextPutAll: (self format: (comparison at: #deltaMrr) places: 6);
							          nextPut: $,;
							          print: (comparison at: #wins);
							          nextPut: $,;
							          print: (comparison at: #ties);
							          nextPut: $,;
							          print: (comparison at: #losses) ]
					          ifFalse: [ stream nextPutAll: ',,,,' ].
				          stream lf ] ] ].
	self write: string to: experiment outputDirectory / 'summary.csv'
]

{ #category : 'writing' }
CooNeuralReport >> writeTraining [
	"The validation curve of every re-ranker trained in this run."

	experiment kinds do: [ :kind |
		experiment baseNames do: [ :base |
			| history string |
			history := (experiment rerankerFor: kind base: base) trainingSummary at: #history ifAbsent: [ nil ].
			history ifNotNil: [
				string := String streamContents: [ :stream |
					          stream
						          nextPutAll: 'epoch,loss,mrr10,recall1,recall3,recall10,baseMrr10,baseRecall1,baseRecall10';
						          lf.
					          history do: [ :line |
						          stream print: (line at: #epoch).
						          #( #loss #mrr #recall1 #recall3 #recall10 #baseMrr #baseRecall1 #baseRecall10 ) do: [ :key |
							          stream
								          nextPut: $,;
								          nextPutAll: (self format: (line at: key ifAbsent: [ 0 ]) places: 6) ].
					          stream lf ] ].
				self write: string to: experiment outputDirectory / 'training' / (kind , '-' , base , '.csv') ] ] ]
]
