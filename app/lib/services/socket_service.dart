import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
      // 1. Abre conexão TCP com o servidor.
      socket = await Socket.connect(
        ip,
        port,
        timeout: connectionTimeout,
      );

      // 2. Cria os 4 bytes que representam
      // o tamanho da imagem em big-endian.
      final ByteData imageSizeData = ByteData(4)
        ..setUint32(
          0,
          imageBytes.length,
          Endian.big,
        );

      final Uint8List imageSizeBytes =
          imageSizeData.buffer.asUint8List();

      // 3. Envia primeiro o tamanho.
      socket.add(imageSizeBytes);

      // 4. Depois envia a imagem JPEG.
      socket.add(imageBytes);

      // Garante que os dados sejam enviados.
      await socket.flush();

      // 5. Aguarda a resposta do servidor.
      //
      // Pelo protocolo definido pela dupla,
      // o servidor encerra a conexão após
      // enviar a resposta completa.
      final BytesBuilder responseBuilder =
          BytesBuilder(copy: false);

      await for (final Uint8List chunk
          in socket.timeout(responseTimeout)) {
        responseBuilder.add(chunk);
      }

      final Uint8List responseData =
          responseBuilder.takeBytes();

      // Precisamos receber pelo menos os
      // 4 bytes que representam o tamanho.
      if (responseData.length < 4) {
        throw Exception(
          'Resposta inválida: tamanho da resposta não recebido.',
        );
      }

      // 6. Lê os primeiros 4 bytes em big-endian.
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
        throw Exception(
          'Resposta inválida: tamanho do JSON é zero.',
        );
      }

      if (responseSize > maxResponseSize) {
        throw Exception(
          'Resposta inválida: tamanho do JSON excede o limite permitido.',
        );
      }

      // 7. Separa os bytes pertencentes ao JSON.
      final Uint8List jsonBytes =
          responseData.sublist(4);

      if (jsonBytes.length != responseSize) {
        throw Exception(
          'Resposta incompleta. '
          'Esperado: $responseSize bytes. '
          'Recebido: ${jsonBytes.length} bytes.',
        );
      }

      // 8. Converte os bytes UTF-8 em String.
      final String jsonResponse =
          utf8.decode(jsonBytes);

      return jsonResponse;
    } on SocketException catch (error) {
      throw Exception(
        'Não foi possível conectar ao servidor: ${error.message}',
      );
    } on TimeoutException {
      throw Exception(
        'Tempo limite excedido na comunicação com o servidor.',
      );
    } finally {
      // A análise acabou ou ocorreu algum erro.
      socket?.destroy();
    }
  }
}