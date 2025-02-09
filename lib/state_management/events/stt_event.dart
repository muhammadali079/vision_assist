import 'package:flutter/material.dart';

abstract class SpeechToTextEvent {}

class InitializeSpeechEvent extends SpeechToTextEvent {}

class StartListeningEvent extends SpeechToTextEvent {
  BuildContext context;
  StartListeningEvent( this.context);
}

class StopListeningEvent extends SpeechToTextEvent {}


class SpeechToTextResultEvent extends SpeechToTextEvent {
  final String result;

  SpeechToTextResultEvent(this.result);
}
