import 'package:equatable/equatable.dart';

abstract class TTSEvent extends Equatable {
  const TTSEvent();

  @override
  List<Object?> get props => [];
}

class StartSpeaking extends TTSEvent {
  final String text;

  const StartSpeaking({required this.text});

  @override
  List<Object?> get props => [text];
}

class StopSpeaking extends TTSEvent {}
