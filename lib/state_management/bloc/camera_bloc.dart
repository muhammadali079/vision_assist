import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testing/state_management/bloc/ocr_bloc.dart';
import 'package:testing/state_management/events/camera_event.dart';
import 'package:testing/state_management/events/ocr_event.dart';
import 'package:testing/state_management/states/camera_state.dart';
import '../../services/camera_services.dart';
import '../../screens/ocr_screen.dart'; // Import OCR screen

class CaptureBloc extends Bloc<CaptureEvent, CaptureState> {
  final CameraService cameraService;
  final OCRBloc ocrBloc;

  CaptureBloc({required this.cameraService, required this.ocrBloc})
      : super(CaptureInitial()) {
    on<CaptureThroughSpeak>(_onCaptureThroughSpeak);
  }

  Future<void> _onCaptureThroughSpeak(
      CaptureThroughSpeak event, Emitter<CaptureState> emit) async {
    try {
      final XFile? capturedImage = await cameraService.captureImage();
      if (capturedImage != null) {
        emit(CaptureImageSuccess(image: capturedImage));

        // **Trigger OCR Processing**
        ocrBloc.add(ProcessOCR(imagePath: capturedImage.path));

        // **Navigate to OCR Screen**
        // ignore: use_build_context_synchronously
        Navigator.push(
          event.context,
          MaterialPageRoute(
            builder: (_) => OCRScreen(imagePath: capturedImage.path),
          ),
        );
      } else {
        emit(const CaptureImageFailure(errorMessage: "Failed to capture image"));
      }
    } catch (e) {
      emit(CaptureImageFailure(errorMessage: "Camera error: $e"));
    }
  }
}
