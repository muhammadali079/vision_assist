import 'package:equatable/equatable.dart';

abstract class OCREvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ProcessOCR extends OCREvent {
  final String imagePath;
  ProcessOCR({required this.imagePath});
  @override
  List<Object?> get props => [imagePath];
}