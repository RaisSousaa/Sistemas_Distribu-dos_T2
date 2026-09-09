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
  static const Duration connectionTimeout =
      Duration(seconds: 5);

  static const Duration responseTimeout =
      Duration(seconds: 15);

  static const int maxResponseSize =
      1024 * 1024; // 1 MB

  Future<String> sendImage({
    required String ip,
    required int port,
    required Uint8List imageBytes,
  }) async {
    Socket? socket;

    try {
      socket = await Socket.connect(
        ip,
        port,
        timeout: connectionTimeout,
      );

      // Tamanho da imagem em 4 bytes, big-endian.
      final ByteData imageSizeData = ByteData(4)
        ..setUint32(
          0,
          imageBytes.length,
          Endian.big,
        );

      socket.add(
        imageSizeData.buffer.asUint8List(),
      );

      socket.add(imageBytes);

      await socket.flush();

      // Recebe toda a resposta até o servidor
      // encerrar a conexão.
      final BytesBuilder responseBuilder =
          BytesBuilder(copy: false);

      await for (final Uint8List chunk
          in socket.timeout(responseTimeout)) {
        responseBuilder.add(chunk);
      }

      final Uint8List responseData =
          responseBuilder.takeBytes();

      if (responseData.length < 4) {
        throw const SocketServiceException(
          'O servidor enviou uma resposta incompleta.',
        );
      }

      // Primeiros 4 bytes = tamanho do JSON.
      final ByteData responseSizeData =
          ByteData.sublistView(
        responseData,
        0,
        4,
      );

      final int responseSize =
          responseSizeData.getUint32(
        0,
        Endian.big,
      );

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

      final Uint8List jsonBytes =
          responseData.sublist(4);

      if (jsonBytes.length != responseSize) {
        throw SocketServiceException(
          'Resposta incompleta do servidor. '
          'Esperado: $responseSize bytes. '
          'Recebido: ${jsonBytes.length} bytes.',
        );
      }

      try {
        return utf8.decode(jsonBytes);
      } on FormatException {
        throw const SocketServiceException(
          'O servidor retornou dados inválidos.',
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
      throw SocketServiceException(
        'Erro inesperado na comunicação: $error',
      );
    } finally {
      socket?.destroy();
    }
  }
}