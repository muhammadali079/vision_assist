import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../state_management/bloc/ocr_bloc.dart';
import '../state_management/bloc/tts_bloc.dart';
import '../state_management/events/tts_event.dart';
import '../state_management/events/ocr_event.dart';
import '../state_management/states/ocr_state.dart';
import '../state_management/states/tts_state.dart';

class OCRScreen extends StatelessWidget {
  final String imagePath;

  const OCRScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    // Trigger OCR processing when entering this screen
    context.read<OCRBloc>().add(ProcessOCR(imagePath: imagePath));

    return Scaffold(
      appBar: AppBar(
        title: const Text("OCR Result"),
        backgroundColor: Colors.deepPurple.shade800,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.read<TTSBloc>().add(StopSpeaking()); // ✅ Stop TTS on back button
            Navigator.pop(context); // Go back to CameraScreen
          },
        ),
      ),
      body: BlocListener<TTSBloc, TTSState>(
        listener: (context, ttsState) {
          if (ttsState is TTSSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Text is being spoken")),
            );
          } else if (ttsState is TTSFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to speak text")),
            );
          }
        },
        child: BlocBuilder<OCRBloc, OCRState>(
          builder: (context, state) {
            if (state is OCRProcessing) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is OCRSuccess) {
              // ✅ Trigger TTS when OCR is successful
              context.read<TTSBloc>().add(StartSpeaking(text: state.extractedText));

              return Column(
                children: [
                  // ✅ Display the captured image
                  Container(
                    margin: const EdgeInsets.all(16),
                    height: 300, // Adjust height as needed
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(File(imagePath)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // ✅ Show extracted text
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Text(
                        state.extractedText,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              );
            } else if (state is OCRFailure) {
              return const Center(child: Text("OCR Failed. Try Again."));
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
