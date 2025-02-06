import 'package:equatable/equatable.dart';

abstract class OCRState extends Equatable {
  @override
  List<Object?> get props => [];
}

class OCRInitial extends OCRState {}
class OCRProcessing extends OCRState {}
class OCRSuccess extends OCRState {
  final String extractedText;
  OCRSuccess({required this.extractedText});
  @override
  List<Object?> get props => [extractedText];
}
class OCRFailure extends OCRState {}
