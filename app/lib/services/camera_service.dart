import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;

  Future<void> initialize() async {
    final cameras = await availableCameras();

    if (cameras.isEmpty) {
      throw Exception('Nenhuma câmera encontrada no dispositivo.');
    }

    final CameraDescription camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
  }

  Future<XFile> takePicture() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      throw Exception('A câmera não foi inicializada.');
    }

    if (controller.value.isTakingPicture) {
      throw Exception('Uma fotografia já está sendo capturada.');
    }

    return controller.takePicture();
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
