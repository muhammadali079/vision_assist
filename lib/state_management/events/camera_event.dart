import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class CaptureEvent extends Equatable {
  const CaptureEvent();
  @override
  List<Object> get props => [];
}

class CaptureThroughSpeak extends CaptureEvent {
  final BuildContext context;

  const CaptureThroughSpeak({required this.context});

  @override
  List<Object> get props => []; 
}
