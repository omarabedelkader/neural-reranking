"
I split Pharo packages into training, validation and test packages.

The split is done by project, not by package: the packages are grouped by the first segment of their
name ('Spec2-Core', 'Spec2-Tests' and 'Spec2-Adapters-Morphic' are all in group 'Spec2'), and a group goes
entirely to one of the three sets. Otherwise the test packages would be near copies of training packages
(e.g. a package and its tests), and the measures would be optimistic.

    split := CooNeuralPackageSplit fromImageWithSeed: 42.
    split := CooNeuralPackageSplit fromImageWithSeed: 42 testPackageNames: #('NECompletion' 'Spec2-Core').
    split := CooNeuralPackageSplit train: #(...) validation: #(...) test: #(...).

With #fromImageWithSeed:testPackageNames:, the groups of the given test packages are removed from the
training and validation packages. The shares of the three sets are 70% / 15% / 15% unless #ratios: gives
others (e.g. #(55 10 35)). The sizes of the three sets can be limited (#maxTrain: ...), the
packages kept are drawn at random (with the seed).
"
Class {
	#name : 'CooNeuralPackageSplit',
	#superclass : 'Object',
	#instVars : [
		'trainPackageNames',
		'validationPackageNames',
		'testPackageNames',
		'seed',
		'ratios'
	],
	#category : 'NeuralReranking-Training',
	#package : 'NeuralReranking-Training'
}

{ #category : 'eligibility' }
CooNeuralPackageSplit class >> eligiblePackages [
	"The packages of the image worth benchmarking: enough methods, and not this project, the benchmarks,
	baselines or manifests."

	^ (PackageOrganizer default packages select: [ :package | self isEligible: package ]) asArray sort: [ :a :b |
		  a name <= b name ]
]

{ #category : 'instance creation' }
CooNeuralPackageSplit class >> fromImageWithSeed: aSeed [

	^ self fromImageWithSeed: aSeed testPackageNames: nil
]

{ #category : 'instance creation' }
CooNeuralPackageSplit class >> fromImageWithSeed: aSeed testPackageNames: aCollectionOrNil [

	^ self fromImageWithSeed: aSeed testPackageNames: aCollectionOrNil ratios: nil
]

{ #category : 'instance creation' }
CooNeuralPackageSplit class >> fromImageWithSeed: aSeed testPackageNames: aCollectionOrNil ratios: someSharesOrNil [
	"someSharesOrNil: the shares of training, validation and test (e.g. #(55 10 35)), nil for 70 / 15 / 15."

	| split |
	split := self new seed: aSeed.
	someSharesOrNil ifNotNil: [ split ratios: someSharesOrNil ].
	^ split
		  splitPackageNames: (self eligiblePackages collect: [ :package | package name asString ])
		  testPackageNames: aCollectionOrNil;
		  yourself
]

{ #category : 'grouping' }
CooNeuralPackageSplit class >> groupOf: aPackageName [

	^ aPackageName asString copyUpTo: $-
]

{ #category : 'eligibility' }
CooNeuralPackageSplit class >> isEligible: aPackage [

	| name count |
	name := aPackage name asString.
	(#( 'BaselineOf' 'ConfigurationOf' 'Manifest' 'NeuralReranking' 'ExtendedHeuristicCompletion' 'Deprecated' )
		 anySatisfy: [ :prefix | name beginsWith: prefix ]) ifTrue: [ ^ false ].
	count := 0.
	aPackage definedClasses do: [ :class |
		class isTrait ifFalse: [ count := count + (aPackage definedMethodsForClass: class) size ] ].
	^ count between: self minimumNumberOfMethods and: self maximumNumberOfMethods
]

{ #category : 'eligibility' }
CooNeuralPackageSplit class >> maximumNumberOfMethods [

	^ 4000
]

{ #category : 'eligibility' }
CooNeuralPackageSplit class >> minimumNumberOfMethods [

	^ 30
]

{ #category : 'instance creation' }
CooNeuralPackageSplit class >> train: someTrainNames validation: someValidationNames test: someTestNames [

	^ self new
		  setTrain: someTrainNames
		  validation: someValidationNames
		  test: someTestNames;
		  yourself
]

{ #category : 'converting' }
CooNeuralPackageSplit >> asDictionary [

	^ Dictionary new
		  at: #seed put: seed;
		  at: #ratios put: self ratios;
		  at: #train put: trainPackageNames;
		  at: #validation put: validationPackageNames;
		  at: #test put: testPackageNames;
		  yourself
]

{ #category : 'checking' }
CooNeuralPackageSplit >> checkDisjoint [

	| train validation test |
	train := trainPackageNames asSet.
	validation := validationPackageNames asSet.
	test := testPackageNames asSet.
	((train includesAny: validation) or: [ (train includesAny: test) or: [ validation includesAny: test ] ])
		ifTrue: [ self error: 'The training, validation and test packages overlap' ]
]

{ #category : 'limiting' }
CooNeuralPackageSplit >> limit: aCollection to: aMaximumOrNil salt: aString [

	(aMaximumOrNil isNil or: [ aMaximumOrNil <= 0 or: [ aCollection size <= aMaximumOrNil ] ]) ifTrue: [
		^ aCollection asArray ].
	^ ((aCollection asArray copy shuffleBy: (Random seed: (seed + (CooNeuralText fnv1a: aString)) \\ 16r7FFFFFFF))
		   first: aMaximumOrNil) sort
]

{ #category : 'limiting' }
CooNeuralPackageSplit >> maxTrain: aTrainMaximum validation: aValidationMaximum test: aTestMaximum [
	"Keep at most these numbers of packages in each set (nil or 0: no limit)."

	trainPackageNames := self limit: trainPackageNames to: aTrainMaximum salt: 'train'.
	validationPackageNames := self limit: validationPackageNames to: aValidationMaximum salt: 'validation'.
	testPackageNames := self limit: testPackageNames to: aTestMaximum salt: 'test'
]

{ #category : 'accessing' }
CooNeuralPackageSplit >> packagesNamed: aCollection [

	^ (aCollection collect: [ :name | PackageOrganizer default packageNamed: name ifAbsent: [ nil ] ]) reject: [
		  :each | each isNil ]
]

{ #category : 'accessing' }
CooNeuralPackageSplit >> ratios [
	"The shares of the packages for training, validation and test, summing to 1."

	^ ratios ifNil: [ #( 0.70 0.15 0.15 ) ]
]

{ #category : 'accessing' }
CooNeuralPackageSplit >> ratios: someShares [
	"The shares of training, validation and test, in any unit (#(55 10 35) or #(0.55 0.1 0.35)).
	Training and validation need a positive share; test may have none."

	| total |
	someShares size = 3 ifFalse: [ self error: 'Three shares are expected: training, validation and test' ].
	(someShares anySatisfy: [ :each | each < 0 ]) ifTrue: [ self error: 'The shares cannot be negative' ].
	(someShares first > 0 and: [ (someShares at: 2) > 0 ]) ifFalse: [
		self error: 'The training and validation shares must be positive' ].
	total := someShares inject: 0 into: [ :sum :each | sum + each ].
	ratios := (someShares collect: [ :each | (each / total) asFloat ]) asArray
]

{ #category : 'accessing' }
CooNeuralPackageSplit >> seed [

	^ seed
]

{ #category : 'accessing' }
CooNeuralPackageSplit >> seed: anInteger [

	seed := anInteger
]

{ #category : 'initialization' }
CooNeuralPackageSplit >> setTrain: someTrainNames validation: someValidationNames test: someTestNames [

	trainPackageNames := (someTrainNames collect: [ :each | each asString ]) asArray sort.
	validationPackageNames := (someValidationNames collect: [ :each | each asString ]) asArray sort.
	testPackageNames := (someTestNames collect: [ :each | each asString ]) asArray sort.
	self checkDisjoint
]

{ #category : 'splitting' }
CooNeuralPackageSplit >> splitPackageNames: aCollection testPackageNames: aTestCollectionOrNil [
	"Split by groups: about 70% of the packages for training, 15% for validation, 15% for test (or the
	shares of #ratios:). When test packages are given, their groups are not used for training nor
	validation, which share the packages in the proportions of their own shares."

	| groups keys train validation test fixedTest targets trainShare validationShare |
	seed ifNil: [ seed := 42 ].
	fixedTest := aTestCollectionOrNil ifNotNil: [ :names | (names collect: [ :each | each asString ]) asArray ].
	groups := Dictionary new.
	aCollection do: [ :name |
		(fixedTest notNil and: [
			 fixedTest anySatisfy: [ :testName | (self class groupOf: testName) = (self class groupOf: name) ] ]) ifFalse: [
			(groups at: (self class groupOf: name) ifAbsentPut: [ OrderedCollection new ]) add: name asString ] ].
	keys := groups keys asArray sort shuffleBy: (Random seed: seed).
	train := OrderedCollection new.
	validation := OrderedCollection new.
	test := OrderedCollection new.
	trainShare := self ratios first.
	validationShare := self ratios at: 2.
	targets := fixedTest
		           ifNil: [ {
				           (train -> trainShare).
				           (validation -> validationShare).
				           (test -> self ratios third) } ]
		           ifNotNil: [
			           ratios
				           ifNil: [ "the shares used before #ratios: existed, kept so that the splits do not change"
					           {
						           (train -> 0.82).
						           (validation -> 0.18) } ]
				           ifNotNil: [ {
						           (train -> (trainShare / (trainShare + validationShare))).
						           (validation -> (validationShare / (trainShare + validationShare))) } ] ].
	keys do: [ :key |
		| total chosen |
		total := train size + validation size + test size + 1.
		"the set the most below its share"
		chosen := (targets detectMin: [ :association | association key size / total - association value ]) key.
		chosen addAll: (groups at: key) ].
	self
		setTrain: train
		validation: validation
		test: (fixedTest ifNil: [ test ])
]

{ #category : 'accessing' }
CooNeuralPackageSplit >> testPackageNames [

	^ testPackageNames
]

{ #category : 'accessing' }
CooNeuralPackageSplit >> testPackages [

	^ self packagesNamed: testPackageNames
]

{ #category : 'accessing' }
CooNeuralPackageSplit >> trainPackageNames [

	^ trainPackageNames
]

{ #category : 'accessing' }
CooNeuralPackageSplit >> trainPackages [

	^ self packagesNamed: trainPackageNames
]

{ #category : 'accessing' }
CooNeuralPackageSplit >> validationPackageNames [

	^ validationPackageNames
]

{ #category : 'accessing' }
CooNeuralPackageSplit >> validationPackages [

	^ self packagesNamed: validationPackageNames
]
