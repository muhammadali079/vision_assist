import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/ocr_services.dart';
import '../events/ocr_event.dart';
import '../states/ocr_state.dart';

class OCRBloc extends Bloc<OCREvent, OCRState> {
  final OCRService ocrService;

  OCRBloc({required this.ocrService}) : super(OCRInitial()) {
    on<ProcessOCR>(_onProcessOCR);
  }

  void _onProcessOCR(ProcessOCR event, Emitter<OCRState> emit) async {
    emit(OCRProcessing());
    try {
      final extractedText = await ocrService.processImage(event.imagePath);
      emit(OCRSuccess(extractedText: extractedText));
    } catch (e) {
      emit(OCRFailure());
    }
  }
}