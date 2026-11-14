"
I compute the features of variable completion candidates, i.e. capitalized globals (mostly class names).

Dense features (see #featureNames): the rank of the candidate in the list of the heuristics, the prefix
and remaining size, how often the global is referenced in the training corpus and in the rest of the package
and of the class, whether it is defined in the package or in the same project (same first segment of the
package name), the similarity of its sub-words with the class being written, whether it is a class, a test
class, and whether the method being written is in a test class.

Sub-words hashed for the embeddings: the candidate ('t:' sub-words, 'T:' the whole name, 'P:' its project)
and the context ('c:' class, 'm:' method selector, 'p:' package).
"
Class {
	#name : 'CooNeuralVariableFeatureExtractor',
	#superclass : 'CooNeuralFeatureExtractor',
	#category : 'NeuralReranking-Core-Features',
	#package : 'NeuralReranking-Core',
	#tag : 'Features'
}

{ #category : 'features' }
CooNeuralVariableFeatureExtractor >> candidateFor: anEntry rank: aRank among: aSize prefix: aPrefix context: aContext [

	| token dense value isClass candidatePackage root corpus index methodKey words |
	token := anEntry contents asSymbol.
	index := aContext packageIndex.
	methodKey := aContext methodKey.
	dense := Array new: 15 withAll: 0.0.
	self fillRankFeaturesOf: aRank among: aSize prefix: aPrefix token: token into: dense.

	corpus := statistics globalCount: token.
	aContext leaveOneOut ifTrue: [ corpus := corpus - ((index methodGlobalsAt: methodKey) occurrencesOf: token) max: 0 ].
	dense at: 6 put: (1 + corpus) ln / 12.0.
	dense at: 7 put: (1 + (index globalCountOf: token excludingMethod: methodKey)) ln / 8.0.
	(index globalCountOf: token excludingMethod: methodKey) > 0 ifTrue: [ dense at: 8 put: 1.0 ].
	(index classGlobalCountOf: token inClass: aContext completionClass excludingMethod: methodKey) > 0 ifTrue: [
		dense at: 9 put: 1.0 ].

	value := Smalltalk globals at: token ifAbsent: [ nil ].
	isClass := value isBehavior.
	candidatePackage := isClass
		                    ifTrue: [ value package ifNotNil: [ :package | package name asString ] ]
		                    ifFalse: [ nil ].
	root := candidatePackage ifNil: [ '' ] ifNotNil: [ :name | name copyUpTo: $- ].
	candidatePackage = index packageName ifTrue: [ dense at: 10 put: 1.0 ].
	(root notEmpty and: [ root = aContext packageRoot ]) ifTrue: [ dense at: 11 put: 1.0 ].
	words := CooNeuralText subwordsOf: token.
	dense at: 12 put: (CooNeuralText jaccardOf: words and: aContext classWords).
	isClass ifTrue: [ dense at: 13 put: 1.0 ].
	(isClass and: [ self isTestClass: value ]) ifTrue: [ dense at: 14 put: 1.0 ].
	aContext isTestContext ifTrue: [ dense at: 15 put: 1.0 ].

	^ CooNeuralCandidate
		  token: token
		  dense: dense
		  fetcher: (anEntry fetcherName ifNil: [ #none ])
		  ids: (self idsOf: words tag: 't:') , {
				  (self idOf: 'T:' , token).
				  (self idOf: 'P:' , root) }
]

{ #category : 'features' }
CooNeuralVariableFeatureExtractor >> contextFor: aNode completionClass: aClass [

	| selector index classWords packageName ids |
	selector := aNode methodNode selector.
	index := (self indexForPackage: (self packageOfClass: aClass selector: selector)) ifNil: [ CooNeuralPackageIndex new ].
	classWords := CooNeuralText subwordsOf: (aClass ifNotNil: [ :class | class instanceSide name ]).
	packageName := index packageName ifNil: [ '' ].
	ids := (self idsOf: classWords tag: 'c:')
	       , (self idsOf: (CooNeuralText subwordsOf: selector) tag: 'm:')
	       , (self idsOf: (CooNeuralText subwordsOf: packageName) tag: 'p:').
	^ CooNeuralContext new
		  packageIndex: index;
		  methodKey: (CooNeuralPackageIndex keyOfClass: aClass selector: selector);
		  completionClass: aClass;
		  classWords: classWords;
		  packageRoot: (packageName copyUpTo: $-);
		  isTestContext: (aClass notNil and: [ self isTestClass: aClass instanceSide ]);
		  leaveOneOut: (self usesLeaveOneOutFor: index);
		  ids: ids;
		  yourself
]

{ #category : 'accessing' }
CooNeuralVariableFeatureExtractor >> featureNames [

	^ #( 'rank-inverse' 'rank-relative' 'rank-log' 'prefix-size' 'remaining-size'
	     'corpus-frequency' 'package-frequency' 'package-used' 'class-used'
	     'package-defined' 'same-project' 'name-overlap'
	     'is-class' 'is-test-class' 'context-is-test' )
]

{ #category : 'testing' }
CooNeuralVariableFeatureExtractor >> isTestClass: aClass [

	^ Smalltalk globals
		  at: #TestCase
		  ifPresent: [ :testCase | aClass isBehavior and: [ aClass instanceSide inheritsFrom: testCase ] ]
		  ifAbsent: [ false ]
]

{ #category : 'accessing' }
CooNeuralVariableFeatureExtractor >> kind [

	^ #variable
]
