import 'dart:typed_data';

import 'package:face_plugin/face_plugin.dart';

class FaceRecognitionService {
  Future<List<double>?> extrairRosto(
    Uint8List imageBytes,
  ) async {
    final faces = await FacePlugin.detectFaces(imageBytes);

    if (faces.isEmpty) {
      return null;
    }

    if (faces.length > 1) {
      throw Exception(
        'Mais de um rosto foi detectado.',
      );
    }

    final face = faces.first;

    if (face.landmarkCount < 3) {
      return null;
    }

    if (face.headEulerAngleY.abs() > 30) {
      return null;
    }

    if (face.headEulerAngleZ.abs() > 25) {
      return null;
    }

    final features =
        await FacePlugin.extractFeatures(imageBytes);

    if (features.length != 1 ||
        features.first.length < 64 ||
        features.first.length > 1024 ||
        features.first.any((value) => !value.isFinite) ||
        features.first.every((value) => value == 0)) {
      return null;
    }

    return features.first;
  }
}