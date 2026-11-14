Class {
	#name : 'CooNeuralTextTest',
	#superclass : 'TestCase',
	#category : 'NeuralReranking-Tests',
	#package : 'NeuralReranking-Tests'
}

{ #category : 'tests' }
CooNeuralTextTest >> testBucketsAreInRange [

	#( 'a' 'nextPutAll:' 'OrderedCollection' '' ) do: [ :string |
		self assert: ((CooNeuralText bucketOf: string among: 7) between: 1 and: 7) ]
]

{ #category : 'tests' }
CooNeuralTextTest >> testFnv1aKnownValues [
	"Reference values of the 32-bit FNV-1a hash: the hash must not depend on the image."

	self assert: (CooNeuralText fnv1a: '') equals: 16r811C9DC5.
	self assert: (CooNeuralText fnv1a: 'a') equals: 16rE40C292C.
	self assert: (CooNeuralText fnv1a: 'foobar') equals: 16rBF9CF968
]

{ #category : 'tests' }
CooNeuralTextTest >> testJaccard [

	self assert: (CooNeuralText jaccardOf: #( 'a' 'b' ) and: #( 'b' 'c' )) equals: 1 / 3.0.
	self assert: (CooNeuralText jaccardOf: #(  ) and: #(  )) equals: 0.0
]

{ #category : 'tests' }
CooNeuralTextTest >> testSubwords [

	self assert: (CooNeuralText subwordsOf: 'nextPutAll:') asArray equals: #( 'next' 'put' 'all' ).
	self assert: (CooNeuralText subwordsOf: 'OCMessageNode') asArray equals: #( 'oc' 'message' 'node' ).
	self assert: (CooNeuralText subwordsOf: 'at:put:') asArray equals: #( 'at' 'put' ).
	self assert: (CooNeuralText subwordsOf: 'Spec2-Core') asArray equals: #( 'spec' 'core' ).
	self assert: (CooNeuralText subwordsOf: nil) isEmpty
]
