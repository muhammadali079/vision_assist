import 'package:camera/camera.dart';

class CameraService {
  late CameraController _cameraController;
  bool _isInitialized = false;

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(cameras.first, ResolutionPreset.high);
      await _cameraController.initialize();
      _isInitialized = true;
    }
  }

  Future<XFile?> captureImage() async {
    if (!_isInitialized || !_cameraController.value.isInitialized) {
      return null;
    }
    return await _cameraController.takePicture();
  }

  CameraController get controller => _cameraController;

  void dispose() {
    _cameraController.dispose();
    _isInitialized = false;
  }
}
