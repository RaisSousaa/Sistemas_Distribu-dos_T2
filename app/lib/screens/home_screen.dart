import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/camera_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _ipController = TextEditingController();

  final TextEditingController _portController =
      TextEditingController(text: '5000');

  final CameraService _cameraService = CameraService();

  bool _isLoading = false;
  bool _cameraReady = false;

  String _result = 'Nenhuma análise realizada.';

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
        _result = 'Erro ao inicializar a câmera: $error';
      });
    }
  }

  Future<void> _analyzeImage() async {
    final String ip = _ipController.text.trim();
    final String port = _portController.text.trim();

    if (ip.isEmpty || port.isEmpty) {
      setState(() {
        _result = 'Informe o IP e a porta do servidor.';
      });

      return;
    }

    if (!_cameraReady) {
      setState(() {
        _result = 'A câmera ainda não está pronta.';
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _result = 'Capturando fotografia...';
    });

    try {
      final XFile photo = await _cameraService.takePicture();

      if (!mounted) {
        return;
      }

      setState(() {
        _result = 'Foto capturada com sucesso.\n\n${photo.path}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _result = 'Erro ao capturar fotografia: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
    final CameraController? cameraController =
        _cameraService.controller;

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
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),

              const SizedBox(height: 24),

              const Text(
                'Servidor',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _ipController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'IP do servidor',
                  hintText: '192.168.0.122',
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
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : Text(
                        _result,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}