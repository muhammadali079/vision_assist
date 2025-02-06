import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/tts_services.dart';
import '../events/tts_event.dart';
import '../states/tts_state.dart';


class TTSBloc extends Bloc<TTSEvent, TTSState> {
  final TTSService ttsService;

  TTSBloc({required this.ttsService}) : super(TTSInitial()) {
    on<StartSpeaking>(_onStartSpeaking);
    on<StopSpeaking>(_onStopSpeaking);
  }

  void _onStartSpeaking(StartSpeaking event, Emitter<TTSState> emit) async {
    emit(TTSInProgress());
    try {
      await ttsService.speak(event.text);
      emit(TTSSuccess());
    } catch (e) {
      emit(TTSFailure());
    }
  }

  void _onStopSpeaking(StopSpeaking event, Emitter<TTSState> emit) async {
    await ttsService.stop();
    emit(TTSStopped());
  }
}
