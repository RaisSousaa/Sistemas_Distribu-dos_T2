import 'dart:convert';

import 'detection.dart';

class DetectionResponse {
  final bool success;
  final List<Detection> objects;
  final String? error;

  const DetectionResponse({
    required this.success,
    required this.objects,
    required this.error,
  });

  factory DetectionResponse.fromJsonString(String jsonString) {
    final dynamic decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Resposta JSON inválida.');
    }

    return DetectionResponse.fromJson(decoded);
  }

  factory DetectionResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'];
    final objects = json['objects'];
    final error = json['error'];

    if (success is! bool) {
      throw const FormatException('Campo "success" inválido.');
    }

    if (objects is! List) {
      throw const FormatException('Campo "objects" inválido.');
    }

    final detections = objects.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Objeto de detecção inválido.');
      }

      return Detection.fromJson(item);
    }).toList();

    return DetectionResponse(
      success: success,
      objects: detections,
      error: error is String ? error : null,
    );
  }
}
