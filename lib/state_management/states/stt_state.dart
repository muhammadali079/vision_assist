abstract class SpeechToTextState {}

class SpeechToTextInitial extends SpeechToTextState {}

class SpeechToTextProcessing extends SpeechToTextState {

}
class SpeechToTextListening extends SpeechToTextState {
   final String result;

  SpeechToTextListening({required this.result}); 
}
class SpeechToTextStopped extends SpeechToTextState {

}

class SpeechToTextSuccess extends SpeechToTextState {
  final String result;

  SpeechToTextSuccess({required this.result});
}

class SpeechToTextFailure extends SpeechToTextState {}
