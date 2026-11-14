"
I am the input of the network for one completion candidate:
- dense: the numerical features (see the #featureNames of the feature extractors),
- fetcher: the name of the fetcher (heuristic) that proposed the candidate, one-hot encoded by the network,
- ids: the hashed sub-words of the candidate, looked up in the embedding table of the network.
"
Class {
	#name : 'CooNeuralCandidate',
	#superclass : 'Object',
	#instVars : [
		'token',
		'dense',
		'fetcher',
		'ids'
	],
	#category : 'NeuralReranking-Core-Features',
	#package : 'NeuralReranking-Core',
	#tag : 'Features'
}

{ #category : 'instance creation' }
CooNeuralCandidate class >> token: aSymbol dense: anArray fetcher: aFetcherName ids: anArrayOfIntegers [

	^ self new
		  setToken: aSymbol
		  dense: anArray
		  fetcher: aFetcherName
		  ids: anArrayOfIntegers
]

{ #category : 'accessing' }
CooNeuralCandidate >> dense [

	^ dense
]

{ #category : 'accessing' }
CooNeuralCandidate >> fetcher [

	^ fetcher
]

{ #category : 'accessing' }
CooNeuralCandidate >> ids [

	^ ids
]

{ #category : 'printing' }
CooNeuralCandidate >> printOn: aStream [

	super printOn: aStream.
	aStream
		nextPut: $(;
		print: token;
		nextPut: $)
]

{ #category : 'initialization' }
CooNeuralCandidate >> setToken: aSymbol dense: anArray fetcher: aFetcherName ids: anArrayOfIntegers [

	token := aSymbol.
	dense := anArray.
	fetcher := aFetcherName.
	ids := anArrayOfIntegers
]

{ #category : 'accessing' }
CooNeuralCandidate >> token [

	^ token
]
