import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class SocketServiceException implements Exception {
  final String message;

  const SocketServiceException(this.message);

  @override
  String toString() => message;
}

class SocketService {
  static const Duration connectionTimeout = Duration(seconds: 5);

  static const Duration responseTimeout = Duration(seconds: 15);

  static const int maxResponseSize = 1024 * 1024; // 1 MB

  Future<String> sendImage({
    required String ip,
    required int port,
    required Uint8List imageBytes,
  }) async {
    Socket? socket;

    try {
      // 1. Abre a conexão TCP.
      socket = await Socket.connect(ip, port, timeout: connectionTimeout);

      // 2. Converte o tamanho da imagem
      // para 4 bytes em big-endian.
      final ByteData imageSizeData = ByteData(4)
        ..setUint32(0, imageBytes.length, Endian.big);

      final Uint8List imageSizeBytes = imageSizeData.buffer.asUint8List();

      // 3. Envia tamanho + imagem.
      socket.add(imageSizeBytes);
      socket.add(imageBytes);

      await socket.flush();

      // 4. Recebe a resposta.
      final BytesBuilder responseBuilder = BytesBuilder(copy: false);

      await for (final Uint8List chunk in socket.timeout(responseTimeout)) {
        responseBuilder.add(chunk);
      }

      final Uint8List responseData = responseBuilder.takeBytes();

      // Precisamos receber pelo menos
      // os 4 bytes do tamanho do JSON.
      if (responseData.length < 4) {
        throw const SocketServiceException(
          'O servidor enviou uma resposta incompleta.',
        );
      }

      // 5. Lê o tamanho do JSON.
      final ByteData responseSizeData = ByteData.sublistView(
        responseData,
        0,
        4,
      );

      final int responseSize = responseSizeData.getUint32(0, Endian.big);

      if (responseSize <= 0) {
        throw const SocketServiceException(
          'O servidor informou um tamanho de resposta inválido.',
        );
      }

      if (responseSize > maxResponseSize) {
        throw const SocketServiceException(
          'A resposta do servidor excede o tamanho permitido.',
        );
      }

      // 6. Obtém somente os bytes do JSON.
      final Uint8List jsonBytes = responseData.sublist(4);

      if (jsonBytes.length != responseSize) {
        throw SocketServiceException(
          'Resposta incompleta do servidor. '
          'Esperado: $responseSize bytes. '
          'Recebido: ${jsonBytes.length} bytes.',
        );
      }

      // 7. Decodifica UTF-8.
      try {
        return utf8.decode(jsonBytes);
      } on FormatException {
        throw const SocketServiceException(
          'O servidor retornou dados que não estão em UTF-8 válido.',
        );
      }
    } on SocketServiceException {
      rethrow;
    } on SocketException {
      throw const SocketServiceException(
        'Não foi possível conectar ao servidor. '
        'Verifique o IP, a porta e se o servidor está ligado.',
      );
    } on TimeoutException {
      throw const SocketServiceException(
        'O servidor demorou muito para responder.',
      );
    } catch (error) {
      throw SocketServiceException('Erro inesperado na comunicação: $error');
    } finally {
      socket?.destroy();
    }
  }
}
