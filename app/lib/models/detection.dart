class Detection {
  final String name;
  final double confidence;

  const Detection({
    required this.name,
    required this.confidence,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final confidence = json['confidence'];

    if (name is! String) {
      throw const FormatException(
        'Campo "name" inválido na detecção.',
      );
    }

    if (confidence is! num) {
      throw const FormatException(
        'Campo "confidence" inválido na detecção.',
      );
    }

    return Detection(
      name: name,
      confidence: confidence.toDouble(),
    );
  }
}