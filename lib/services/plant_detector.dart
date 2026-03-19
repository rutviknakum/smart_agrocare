import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img_lib;

class PlantDetector {
  Interpreter? _interpreter;
  Map<String, int> _labels = {};
  bool _isLoaded = false;
  bool _isOutputUint8 = false;

  Future<void> loadModel() async {
    try {
      print("🔍 Loading TFLite model...");

      // Load model
      _interpreter = await Interpreter.fromAsset(
        'assets/models/plant_disease_model.tflite',
      );

      // ✅ Get model tensor details
      final inputDetails = _interpreter!.getInputTensors();
      final outputDetails = _interpreter!.getOutputTensors();

      print("✅ Input shape: ${inputDetails[0].shape}");
      print("✅ Input type: ${inputDetails[0].type}");
      print("✅ Output shape: ${outputDetails[0].shape}");
      print("✅ Output type: ${outputDetails[0].type}");

      // ✅ Check if output is uint8 or float32
      _isOutputUint8 = (outputDetails[0].type == TensorType.uint8);
      print("✅ Output is uint8: $_isOutputUint8");

      // Load class labels
      final jsonString = await rootBundle.loadString('assets/categories.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      _labels = jsonData.map((key, value) => MapEntry(key, value as int));

      _isLoaded = true;
      print(
        "✅ Model loaded successfully! ${_labels.length} classes: ${_labels.keys.toList()}",
      );
    } catch (e) {
      print("❌ Model load error: $e");
      _isLoaded = false;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> predictImage(String imagePath) async {
    if (!_isLoaded || _interpreter == null) {
      throw Exception("Model not loaded");
    }

    print("🔍 [AI] Processing image...");

    try {
      // Load and decode image
      final imageBytes = await File(imagePath).readAsBytes();
      img_lib.Image? image = img_lib.decodeImage(imageBytes);
      if (image == null) {
        throw Exception("Cannot decode image");
      }

      print("📸 Original image: ${image.width}x${image.height}");

      // Resize to model input size (224x224)
      image = img_lib.copyResize(image, width: 224, height: 224);

      // ✅ Create uint8 input tensor
      final inputData = _createInputTensor(image);
      print("✅ Raw input: ${inputData.length} elements");

      // ✅ Reshape to 4D [1, 224, 224, 3]
      final inputTensor = inputData.reshape([1, 224, 224, 3]);
      print("✅ SHAPED tensor: ${inputTensor.shape}");

      // ✅ Create appropriate output tensor based on model type
      List<double> scores;

      if (_isOutputUint8) {
        // Model outputs uint8 - don't reshape, keep as flat Uint8List
        final outputUint8 = Uint8List(_labels.length);
        _interpreter!.run(inputTensor, outputUint8);

        // Convert uint8 to normalized float scores
        scores = _normalizeUint8Output(outputUint8);
        print("✅ Normalized uint8 scores: $scores");
      } else {
        // Model outputs float32
        final outputFloat = List<double>.filled(_labels.length, 0.0);
        _interpreter!.run(inputTensor, outputFloat);

        scores = outputFloat;
        print("✅ Float scores: $scores");
      }

      final prediction = _getTopPrediction(scores);

      print(
        "🎯 ✅ SUCCESS: ${prediction['disease']} (${(prediction['confidence'] * 100).toStringAsFixed(1)}%)",
      );

      return {
        'disease': prediction['disease'],
        'confidence': prediction['confidence'],
      };
    } catch (e) {
      print("❌ Prediction error: $e");
      rethrow;
    }
  }

  /// ✅ Creates uint8 tensor [224, 224, 3] (0-255 range)
  Uint8List _createInputTensor(img_lib.Image image) {
    final input = Uint8List(1 * 224 * 224 * 3);
    int pixelIndex = 0;

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = image.getPixel(x, y);

        // ✅ Properly handle num type from image package
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        input[pixelIndex++] = r.clamp(0, 255);
        input[pixelIndex++] = g.clamp(0, 255);
        input[pixelIndex++] = b.clamp(0, 255);
      }
    }

    return input;
  }

  /// ✅ Normalize uint8 output (0-255) to confidence scores (0-1)
  List<double> _normalizeUint8Output(Uint8List quantizedOutput) {
    final scores = <double>[];

    // Simple normalization: divide by 255 to get 0-1 range
    for (int i = 0; i < quantizedOutput.length; i++) {
      scores.add(quantizedOutput[i] / 255.0);
    }

    return scores;
  }

  Map<String, dynamic> _getTopPrediction(List<double> scores) {
    double maxConfidence = scores[0];
    int predictedIndex = 0;

    // Find highest confidence score
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > maxConfidence) {
        maxConfidence = scores[i];
        predictedIndex = i;
      }
    }

    // Map index to disease name
    final predictedDisease = _labels.keys.firstWhere(
      (label) => _labels[label] == predictedIndex,
      orElse: () => "Unknown",
    );

    return {
      'disease': predictedDisease,
      'confidence': maxConfidence,
      'index': predictedIndex,
    };
  }

  void dispose() {
    _interpreter?.close();
    print("🧹 Model disposed");
  }

  bool get isLoaded => _isLoaded;
}
