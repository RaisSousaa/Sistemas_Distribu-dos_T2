import 'dart:io';

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

  String? _capturedImagePath;

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
      // 1. Captura a fotografia.
      final XFile photo = await _cameraService.takePicture();

      if (!mounted) {
        return;
      }

      // A partir daqui, a interface passa
      // a exibir a fotografia capturada.
      setState(() {
        _capturedImagePath = photo.path;
        _statusMessage = 'Preparando imagem...';
      });

      // 2. Redimensiona e comprime.
      final PreparedImage preparedImage = await _imageService.prepareImage(
        photo.path,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Enviando imagem para o servidor...';
      });

      // 3. Envia pelo socket TCP.
      final String jsonResponse = await _socketService.sendImage(
        ip: ip,
        port: port,
        imageBytes: preparedImage.bytes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Analisando resultado...';
      });

      // 4. Interpreta a resposta JSON.
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

  void _newAnalysis() {
    setState(() {
      _capturedImagePath = null;
      _detections = [];
      _statusMessage = 'Pronto para uma nova análise.';
    });
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

  Widget _buildImageArea() {
    final CameraController? cameraController = _cameraService.controller;

    // Se já existe uma fotografia capturada,
    // mostra exatamente a imagem enviada.
    if (_capturedImagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Image.file(File(_capturedImagePath!), fit: BoxFit.cover),
        ),
      );
    }

    // Caso contrário, mostra câmera ao vivo.
    if (_cameraReady &&
        cameraController != null &&
        cameraController.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: cameraController.value.aspectRatio,
          child: CameraPreview(cameraController),
        ),
      );
    }

    return const SizedBox(
      height: 300,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildResultContent() {
    if (_isLoading) {
      return Column(
        children: [
          const CircularProgressIndicator(),

          const SizedBox(height: 16),

          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
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
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle),

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
    final bool hasCapturedImage = _capturedImagePath != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detector de Objetos'),
        centerTitle: true,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImageArea(),

              const SizedBox(height: 24),

              const Text(
                'Conexão com o servidor',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _ipController,
                enabled: !_isLoading && !hasCapturedImage,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'IP do servidor',
                  hintText: '192.168.1.100',
                  prefixIcon: Icon(Icons.lan),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _portController,
                enabled: !_isLoading && !hasCapturedImage,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Porta',
                  hintText: '5000',
                  prefixIcon: Icon(Icons.settings_ethernet),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              if (!hasCapturedImage)
                FilledButton.icon(
                  onPressed: _isLoading ? null : _analyzeImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Tirar e Analisar'),
                  ),
                ),

              if (hasCapturedImage && !_isLoading)
                OutlinedButton.icon(
                  onPressed: _newAnalysis,
                  icon: const Icon(Icons.refresh),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Nova análise'),
                  ),
                ),

              const SizedBox(height: 28),

              const Text(
                'Resultado',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildResultContent(),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
