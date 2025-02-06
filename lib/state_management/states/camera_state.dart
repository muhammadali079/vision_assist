import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';

abstract class CaptureState extends Equatable {
  const CaptureState();
  @override
  List<Object?> get props => [];
}

class CaptureInitial extends CaptureState {}

class CaptureClose extends CaptureState {}

class CaptureImageSuccess extends CaptureState {
  final XFile image;
  const CaptureImageSuccess({required this.image});
  
  @override
  List<Object?> get props => [image];
}

class CaptureImageFailure extends CaptureState {
  final String errorMessage;
  const CaptureImageFailure({required this.errorMessage});
  
  @override
  List<Object?> get props => [errorMessage];
}
