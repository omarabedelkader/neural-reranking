Class {
	#name : 'CooNeuralPackageSplitTest',
	#superclass : 'TestCase',
	#category : 'NeuralReranking-Tests',
	#package : 'NeuralReranking-Tests'
}

{ #category : 'helpers' }
CooNeuralPackageSplitTest >> names [

	^ #( 'Alpha' 'Alpha-Tests' 'Beta-Core' 'Beta-Tests' 'Gamma' 'Delta-Core' 'Delta-UI' 'Epsilon' 'Zeta'
	     'Eta-Core' 'Theta' 'Iota' 'Kappa-Core' 'Kappa-Tests' 'Lambda' 'Mu' 'Nu' 'Xi' 'Omicron' 'Pi' )
]

{ #category : 'helpers' }
CooNeuralPackageSplitTest >> split: aSeed [

	^ CooNeuralPackageSplit new
		  seed: aSeed;
		  splitPackageNames: self names testPackageNames: nil;
		  yourself
]

{ #category : 'tests' }
CooNeuralPackageSplitTest >> testExplicitTestPackagesRemoveTheirProjects [

	| split |
	split := CooNeuralPackageSplit new
		         seed: 1;
		         splitPackageNames: self names testPackageNames: #( 'Beta-Core' );
		         yourself.
	self assert: split testPackageNames equals: #( 'Beta-Core' ).
	self deny: (split trainPackageNames includes: 'Beta-Tests').
	self deny: (split validationPackageNames includes: 'Beta-Tests')
]

{ #category : 'tests' }
CooNeuralPackageSplitTest >> testLimits [

	| split |
	split := self split: 42.
	split maxTrain: 3 validation: 1 test: 1.
	self assert: split trainPackageNames size equals: 3.
	self assert: split validationPackageNames size equals: 1.
	self assert: split testPackageNames size equals: 1
]

{ #category : 'tests' }
CooNeuralPackageSplitTest >> testOverlappingExplicitSplitIsRejected [

	self should: [ CooNeuralPackageSplit train: #( 'A' 'B' ) validation: #( 'C' ) test: #( 'B' ) ] raise: Error
]

{ #category : 'tests' }
CooNeuralPackageSplitTest >> testSplitIsByProjectDisjointAndReproducible [

	| split groups |
	split := self split: 42.
	self assert: split trainPackageNames size + split validationPackageNames size + split testPackageNames size
		equals: self names size.
	self assert: split testPackageNames notEmpty.
	self assert: split validationPackageNames notEmpty.
	groups := [ :names | (names collect: [ :name | CooNeuralPackageSplit groupOf: name ]) asSet ].
	self deny: ((groups value: split trainPackageNames) includesAny: (groups value: split testPackageNames)).
	self deny: ((groups value: split trainPackageNames) includesAny: (groups value: split validationPackageNames)).
	self assert: (self split: 42) asDictionary equals: split asDictionary
]
