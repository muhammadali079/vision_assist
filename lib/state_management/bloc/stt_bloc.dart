import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testing/services/stt_services.dart';
import 'package:testing/state_management/bloc/camera_bloc.dart';
import 'package:testing/state_management/events/camera_event.dart';
import 'package:testing/state_management/events/stt_event.dart';
import 'package:testing/state_management/states/stt_state.dart';


class SpeechToTextBloc extends Bloc<SpeechToTextEvent, SpeechToTextState> {
  final SpeechToTextService speechToTextService;

  SpeechToTextBloc({required this.speechToTextService}) : super(SpeechToTextInitial()) {
    on<InitializeSpeechEvent>(_onInitializeSpeech);
    on<StartListeningEvent>(_onStartListening);
    on<StopListeningEvent>(_onStopListening); 
  }

  void _onInitializeSpeech(InitializeSpeechEvent event, Emitter<SpeechToTextState> emit) async {
    emit(SpeechToTextProcessing());
    try {
      bool initialized = await speechToTextService.initialize();
      if (initialized) {
        emit(SpeechToTextSuccess(result: "Speech Initialized"));
      } else {
        emit(SpeechToTextFailure());
      }
    } catch (e) {
      emit(SpeechToTextFailure());
    }
  }

void _onStartListening(StartListeningEvent event, Emitter<SpeechToTextState> emit) async {
  emit(SpeechToTextProcessing());
  try {
    speechToTextService.startListening((result) {
      // If the recognized text contains the word "capture", trigger the capture event
         print("Speech result: $result");
      if (result.contains("capture")) {
        // Dispatch CaptureThroughSpeak to CaptureBloc
        BlocProvider.of<CaptureBloc>(event.context).add(CaptureThroughSpeak(context: event.context));
        
      }
      add(SpeechToTextResultEvent(result));
    });
    emit(SpeechToTextSuccess(result: "Listening started"));
  } catch (e) {
    emit(SpeechToTextFailure());
  }
}


  void _onStopListening(StopListeningEvent event, Emitter<SpeechToTextState> emit) async {
    speechToTextService.stopListening();
    emit(SpeechToTextSuccess(result: "Listening stopped"));
  }
}
