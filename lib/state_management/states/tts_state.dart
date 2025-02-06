import 'package:equatable/equatable.dart';

abstract class TTSState extends Equatable {
  const TTSState();

  @override
  List<Object?> get props => [];
}

class TTSInitial extends TTSState {}

class TTSInProgress extends TTSState {}

class TTSSuccess extends TTSState {}

class TTSFailure extends TTSState {}

class TTSStopped extends TTSState {}
