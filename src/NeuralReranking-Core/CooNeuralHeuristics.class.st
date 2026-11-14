"
I build the three Complishon configurations the re-ranker is trained on and compared with, for message
and for variable (class name) completion. They are the ones of HeuristicCompletion-History, which work on
Pharo 14 (CoGlobalSorterResultSetBuilder used by CooBenchRunnerVariables>>#completeBaseline is gone).

- #baseline (flat): messages: all the selectors of the image (CoUnknownMessageHeuristic);
                    variables: all the globals (CoGlobalVariablesHeuristic).
- #semantics: the default Complishon heuristics (self, super, typed receivers, literals, ..., then all selectors;
              local, workspace, instance variables, then globals).
- #dependency: #semantics, plus the selectors / classes of the direct package dependencies before
               the global fallback.

    CooNeuralHeuristics builderFor: #semantics kind: #message.
"
Class {
	#name : 'CooNeuralHeuristics',
	#superclass : 'Object',
	#category : 'NeuralReranking-Core-Heuristics',
	#package : 'NeuralReranking-Core',
	#tag : 'Heuristics'
}

{ #category : 'message builders' }
CooNeuralHeuristics class >> baselineMessageBuilder [

	| builder |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder messagesHeuristic: (builder newHeuristicBuilder
			 add: CoUnknownMessageHeuristic new;
			 build).
	^ builder
]

{ #category : 'variable builders' }
CooNeuralHeuristics class >> baselineVariableBuilder [

	| builder |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoGlobalVariablesHeuristic new;
			 build).
	^ builder
]

{ #category : 'building' }
CooNeuralHeuristics class >> builderFor: aConfigurationName kind: aKind [

	(self configurationNames includes: aConfigurationName asSymbol) ifFalse: [
		^ self error: 'Unknown configuration: ' , aConfigurationName printString ].
	(#( #message #variable ) includes: aKind asSymbol) ifFalse: [
		^ self error: 'Unknown completion kind: ' , aKind printString ].
	^ self perform: (aConfigurationName , aKind capitalized , 'Builder') asSymbol
]

{ #category : 'accessing' }
CooNeuralHeuristics class >> configurationNames [

	^ #( #baseline #semantics #dependency )
]

{ #category : 'message builders' }
CooNeuralHeuristics class >> dependencyMessageBuilder [

	| builder |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder messagesHeuristic: (builder newHeuristicBuilder
			 add: CoSelfMessageHeuristic new;
			 add: CoSuperMessageHeuristic new;
			 add: CoTypedReceiverMessageHeuristic new;
			 add: CoInitializeInferencedMessageHeuristic new;
			 add: CoLiteralMessageHeuristic new;
			 add: CoGlobalVariableMessageHeuristic new;
			 add: CoVariableWithTypeNameMessageHeuristic new;
			 add: CooNeuralDependencyMessageHeuristic new;
			 add: CoUnknownMessageHeuristic new;
			 build).
	^ builder
]

{ #category : 'variable builders' }
CooNeuralHeuristics class >> dependencyVariableBuilder [

	| builder |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass: CooNeuralDependencyGlobalVariableFetcher);
			 add: CoGlobalVariablesHeuristic new;
			 build).
	^ builder
]

{ #category : 'accessing' }
CooNeuralHeuristics class >> labelOf: aConfigurationName [

	^ aConfigurationName asString capitalized
]

{ #category : 'message builders' }
CooNeuralHeuristics class >> semanticsMessageBuilder [

	| builder |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder messagesHeuristic: (builder newHeuristicBuilder
			 add: CoSelfMessageHeuristic new;
			 add: CoSuperMessageHeuristic new;
			 add: CoTypedReceiverMessageHeuristic new;
			 add: CoInitializeInferencedMessageHeuristic new;
			 add: CoLiteralMessageHeuristic new;
			 add: CoGlobalVariableMessageHeuristic new;
			 add: CoVariableWithTypeNameMessageHeuristic new;
			 add: CoUnknownMessageHeuristic new;
			 build).
	^ builder
]

{ #category : 'variable builders' }
CooNeuralHeuristics class >> semanticsVariableBuilder [

	| builder |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: CoGlobalVariablesHeuristic new;
			 build).
	^ builder
]
