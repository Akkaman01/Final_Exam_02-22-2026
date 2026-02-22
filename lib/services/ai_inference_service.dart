import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class AiLabelCandidate {
  final String label;
  final double confidence;

  const AiLabelCandidate({required this.label, required this.confidence});
}

class AiInferenceResult {
  final String label;
  final double confidence;
  final List<AiLabelCandidate> topCandidates;

  const AiInferenceResult({
    required this.label,
    required this.confidence,
    required this.topCandidates,
  });
}

class AiInferenceService {
  AiInferenceService._();
  static final AiInferenceService instance = AiInferenceService._();

  static const _modelAsset = 'assets/models/MobileNet_V2.tflite';
  static const _labelsAsset = 'assets/models/labels.txt';
  static const _topK = 5;

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _initialized = false;

  Future<void> loadModel() async {
    if (_initialized) return;

    _interpreter = await Interpreter.fromAsset(_modelAsset);
    final labelsRaw = await rootBundle.loadString(_labelsAsset);
    _labels = labelsRaw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    _initialized = true;
  }

  Future<AiInferenceResult> classifyImage(String imagePath) async {
    await loadModel();
    if (_interpreter == null) {
      return const AiInferenceResult(
        label: 'unknown',
        confidence: 0.0,
        topCandidates: [],
      );
    }

    final bytes = await _readImageBytes(imagePath);
    if (bytes == null) {
      return const AiInferenceResult(
        label: 'unknown',
        confidence: 0.0,
        topCandidates: [],
      );
    }

    final image = img.decodeImage(Uint8List.fromList(bytes));
    if (image == null) {
      return const AiInferenceResult(
        label: 'unknown',
        confidence: 0.0,
        topCandidates: [],
      );
    }

    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);
    final inputShape = inputTensor.shape;
    final outputShape = outputTensor.shape;
    final inputType = inputTensor.type;
    final outputType = outputTensor.type;

    final h = inputShape[1];
    final w = inputShape[2];
    final c = inputShape[3];
    if (c != 3) {
      return const AiInferenceResult(
        label: 'unknown',
        confidence: 0.0,
        topCandidates: [],
      );
    }

    final resized = img.copyResize(image, width: w, height: h);
    final input = _buildInput(resized, inputType, h, w);
    final classes = outputShape.last;

    List<double> scores;
    if (outputType == TensorType.float32) {
      final output = List.generate(1, (_) => List<double>.filled(classes, 0.0));
      _interpreter!.run(input, output);
      scores = output.first;
    } else {
      final output = List.generate(1, (_) => List<int>.filled(classes, 0));
      _interpreter!.run(input, output);
      scores = output.first.map((e) => e / 255.0).toList();
    }

    final ranked = _topIndices(scores, _topK);
    final candidates = ranked
        .map(
          (i) => AiLabelCandidate(
            label: _labelAt(i),
            confidence: scores[i].clamp(0.0, 1.0),
          ),
        )
        .toList();

    if (candidates.isEmpty) {
      return const AiInferenceResult(
        label: 'unknown',
        confidence: 0.0,
        topCandidates: [],
      );
    }

    return AiInferenceResult(
      label: candidates.first.label,
      confidence: candidates.first.confidence,
      topCandidates: candidates,
    );
  }

  Future<List<int>?> _readImageBytes(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        final client = HttpClient();
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          client.close();
          return null;
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response) {
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        client.close();
        return bytes;
      } catch (_) {
        return null;
      }
    }

    try {
      return await File(trimmed).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Object _buildInput(img.Image image, TensorType inputType, int h, int w) {
    if (inputType == TensorType.float32) {
      return [
        List.generate(h, (y) {
          return List.generate(w, (x) {
            final pixel = image.getPixel(x, y);
            return [
              (pixel.r / 127.5) - 1.0,
              (pixel.g / 127.5) - 1.0,
              (pixel.b / 127.5) - 1.0,
            ];
          });
        }),
      ];
    }

    return [
      List.generate(h, (y) {
        return List.generate(w, (x) {
          final pixel = image.getPixel(x, y);
          return [pixel.r, pixel.g, pixel.b];
        });
      }),
    ];
  }

  List<int> _topIndices(List<double> scores, int k) {
    final indexed = List<int>.generate(scores.length, (i) => i);
    indexed.sort((a, b) => scores[b].compareTo(scores[a]));
    return indexed.take(k).toList();
  }

  String _labelAt(int index) {
    if (index < 0 || index >= _labels.length) return 'unknown';
    return _labels[index];
  }

  String mapLabelToViolationName(String label) {
    final l = label.toLowerCase();

    if (l.contains('wallet') || l.contains('purse') || l.contains('envelope')) {
      return 'ซื้อสิทธิ์ขายเสียง';
    }
    if (l.contains('minibus') || l.contains('cab') || l.contains('taxi')) {
      return 'ขนคนไปลงคะแนน';
    }
    if (l.contains('water bottle') ||
        l.contains('bottle') ||
        l.contains('cup')) {
      return 'แจกสิ่งของ';
    }
    return '';
  }

  String mapResultToViolationName(AiInferenceResult result) {
    for (final c in result.topCandidates) {
      final mapped = mapLabelToViolationName(c.label);
      if (mapped.isNotEmpty) {
        return mapped;
      }
    }
    return mapLabelToViolationName(result.label);
  }
}
