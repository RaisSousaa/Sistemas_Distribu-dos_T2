import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/detection.dart';
import 'package:app/models/detection_response.dart';

void main() {
  group('Modelos e Protocolo JSON da Aplicação', () {
    test('Deve desserializar Detection individual corretamente', () {
      final json = {'name': 'person', 'confidence': 0.95};
      final detection = Detection.fromJson(json);

      expect(detection.name, 'person');
      expect(detection.confidence, 0.95);
    });

    test('Deve lançar FormatException para Detection com campos inválidos', () {
      expect(() => Detection.fromJson({'name': 123, 'confidence': 0.9}),
          throwsFormatException);
      expect(() => Detection.fromJson({'name': 'chair', 'confidence': 'invalid'}),
          throwsFormatException);
    });

    test('Deve interpretar resposta de sucesso com objetos detectados', () {
      const jsonStr = '''{
        "success": true,
        "objects": [
          {"name": "person", "confidence": 0.95},
          {"name": "chair", "confidence": 0.87}
        ],
        "error": null
      }''';

      final response = DetectionResponse.fromJsonString(jsonStr);

      expect(response.success, isTrue);
      expect(response.objects.length, 2);
      expect(response.objects[0].name, 'person');
      expect(response.objects[0].confidence, 0.95);
      expect(response.objects[1].name, 'chair');
      expect(response.objects[1].confidence, 0.87);
      expect(response.error, isNull);
    });

    test('Deve interpretar resposta de sucesso quando nenhum objeto for detectado', () {
      const jsonStr = '''{
        "success": true,
        "objects": [],
        "error": null
      }''';

      final response = DetectionResponse.fromJsonString(jsonStr);

      expect(response.success, isTrue);
      expect(response.objects, isEmpty);
      expect(response.error, isNull);
    });

    test('Deve interpretar resposta de erro enviada pelo servidor', () {
      const jsonStr = '''{
        "success": false,
        "objects": [],
        "error": "Falha ao decodificar a imagem."
      }''';

      final response = DetectionResponse.fromJsonString(jsonStr);

      expect(response.success, isFalse);
      expect(response.objects, isEmpty);
      expect(response.error, 'Falha ao decodificar a imagem.');
    });

    test('Deve lançar FormatException em JSON com formato inválido', () {
      const invalidJson = 'não é um json válido';
      expect(() => DetectionResponse.fromJsonString(invalidJson),
          throwsFormatException);
    });
  });
}

