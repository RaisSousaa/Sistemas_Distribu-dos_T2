import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/detection.dart';
import '../models/detection_response.dart';
import '../services/camera_service.dart';
import '../services/image_service.dart';
import '../services/socket_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _ipController = TextEditingController();

  final TextEditingController _portController = TextEditingController(
    text: '5000',
  );

  final CameraService _cameraService = CameraService();
  final ImageService _imageService = ImageService();
  final SocketService _socketService = SocketService();

  bool _isLoading = false;
  bool _cameraReady = false;

  String _statusMessage = 'Nenhuma análise realizada.';

  List<Detection> _detections = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        _cameraReady = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Erro ao inicializar a câmera: $error';
      });
    }
  }

  bool _isValidIpv4(String ip) {
    final parts = ip.split('.');

    if (parts.length != 4) {
      return false;
    }

    for (final part in parts) {
      if (part.isEmpty) {
        return false;
      }

      final int? value = int.tryParse(part);

      if (value == null || value < 0 || value > 255) {
        return false;
      }
    }

    return true;
  }

  Future<void> _analyzeImage() async {
    final String ip = _ipController.text.trim();

    final String portText = _portController.text.trim();

    if (ip.isEmpty || portText.isEmpty) {
      setState(() {
        _statusMessage = 'Informe o IP e a porta do servidor.';
        _detections = [];
      });

      return;
    }

    if (!_isValidIpv4(ip)) {
      setState(() {
        _statusMessage = 'Informe um endereço IP válido.';
        _detections = [];
      });

      return;
    }

    final int? port = int.tryParse(portText);

    if (port == null || port < 1 || port > 65535) {
      setState(() {
        _statusMessage = 'Informe uma porta válida.';
        _detections = [];
      });

      return;
    }

    if (!_cameraReady) {
      setState(() {
        _statusMessage = 'A câmera ainda não está pronta.';
        _detections = [];
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Capturando fotografia...';
      _detections = [];
    });

    try {
      final XFile photo = await _cameraService.takePicture();

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Preparando imagem...';
      });

      final PreparedImage preparedImage = await _imageService.prepareImage(
        photo.path,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Enviando imagem para o servidor...';
      });

      final String jsonResponse = await _socketService.sendImage(
        ip: ip,
        port: port,
        imageBytes: preparedImage.bytes,
      );

      final DetectionResponse response = DetectionResponse.fromJsonString(
        jsonResponse,
      );

      if (!mounted) {
        return;
      }

      if (!response.success) {
        setState(() {
          _statusMessage = response.error ?? 'O servidor informou um erro.';
          _detections = [];
        });

        return;
      }

      if (response.objects.isEmpty) {
        setState(() {
          _statusMessage = 'Nada Detectado';
          _detections = [];
        });

        return;
      }

      setState(() {
        _statusMessage = 'Objetos detectados:';
        _detections = response.objects;
      });
    } on SocketServiceException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = error.message;
        _detections = [];
      });
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            'Resposta inválida do servidor: '
            '${error.message}';

        _detections = [];
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Ocorreu um erro inesperado.';
        _detections = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _translateObjectName(String name) {
    const translations = {
      'person': 'Pessoa',
      'chair': 'Cadeira',
      'backpack': 'Mochila',
      'car': 'Carro',
      'motorcycle': 'Motocicleta',
      'bicycle': 'Bicicleta',
      'bus': 'Ônibus',
      'truck': 'Caminhão',
      'dog': 'Cachorro',
      'cat': 'Gato',
      'bottle': 'Garrafa',
      'cell phone': 'Celular',
      'laptop': 'Notebook',
      'book': 'Livro',
      'cup': 'Copo',
      'dining table': 'Mesa',
    };

    return translations[name.toLowerCase()] ?? _capitalize(name);
  }

  String _capitalize(String text) {
    if (text.isEmpty) {
      return text;
    }

    return '${text[0].toUpperCase()}'
        '${text.substring(1)}';
  }

  Widget _buildResultContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_detections.isEmpty) {
      return Text(_statusMessage, style: const TextStyle(fontSize: 16));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _statusMessage,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 16),

        ..._detections.map((detection) {
          final String translatedName = _translateObjectName(detection.name);

          final double percentage = detection.confidence * 100;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$translatedName detectado',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Confiança: '
                        '${percentage.toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _cameraService.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? cameraController = _cameraService.controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detector de Objetos'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_cameraReady &&
                  cameraController != null &&
                  cameraController.value.isInitialized)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: cameraController.value.aspectRatio,
                    child: CameraPreview(cameraController),
                  ),
                )
              else
                const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),

              const SizedBox(height: 24),

              const Text(
                'Servidor',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _ipController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'IP do servidor',
                  hintText: '192.168.1.100',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Porta',
                  hintText: '5000',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _analyzeImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tirar e Analisar'),
              ),

              const SizedBox(height: 32),

              const Text(
                'Resultado',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildResultContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
