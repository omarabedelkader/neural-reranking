"
I hold the small text utilities of the neural re-ranker:

- a stable string hash (FNV-1a on 32 bits). String>>#hash may change from one image to another,
  so a model trained in one image would look up other embedding buckets in another one;
- a splitter of identifiers into lower-case sub-words: camel case, keywords, digits and underscores
  are word boundaries, and an acronym stays one word ('OCMessageNode' -> 'oc' 'message' 'node');
- the Jaccard similarity of two collections of words.
"
Class {
	#name : 'CooNeuralText',
	#superclass : 'Object',
	#category : 'NeuralReranking-Core-Features',
	#package : 'NeuralReranking-Core',
	#tag : 'Features'
}

{ #category : 'hashing' }
CooNeuralText class >> bucketOf: aString among: numberOfBuckets [
	"Answer a bucket between 1 and numberOfBuckets."

	^ (self fnv1a: aString) \\ numberOfBuckets + 1
]

{ #category : 'hashing' }
CooNeuralText class >> fnv1a: aString [

	| hash |
	hash := 2166136261.
	aString asString do: [ :character |
		hash := (hash bitXor: (character asInteger bitAnd: 16rFFFF)) * 16777619 bitAnd: 16rFFFFFFFF ].
	^ hash
]

{ #category : 'similarity' }
CooNeuralText class >> jaccardOf: aCollection and: anotherCollection [

	| first second union |
	first := aCollection asSet.
	second := anotherCollection asSet.
	union := first size + second size - (first count: [ :each | second includes: each ]).
	union = 0 ifTrue: [ ^ 0.0 ].
	^ (first count: [ :each | second includes: each ]) / union asFloat
]

{ #category : 'splitting' }
CooNeuralText class >> subwordsOf: aStringOrNil [

	| string words current previous flush |
	words := OrderedCollection new.
	aStringOrNil ifNil: [ ^ words ].
	string := aStringOrNil asString.
	current := WriteStream on: (String new: 16).
	flush := [
	         current position > 0 ifTrue: [ words add: current contents asLowercase ].
	         current := WriteStream on: (String new: 16) ].
	previous := nil.
	string withIndexDo: [ :character :index |
		character isLetter
			ifFalse: [ flush value ]
			ifTrue: [
				| next |
				next := index < string size
					        ifTrue: [ string at: index + 1 ]
					        ifFalse: [ nil ].
				(character isUppercase and: [
					 previous notNil and: [
						 previous isLetter and: [ previous isLowercase or: [ next notNil and: [ next isLowercase ] ] ] ] ])
					ifTrue: [ flush value ].
				current nextPut: character ].
		previous := character ].
	flush value.
	^ words
]
