import 'package:flutter/foundation.dart';

class FaceTestConfig {
  // A foto de teste existe somente no navegador em modo de desenvolvimento.
  // Android/iOS e builds de release sempre usam a câmera e a biometria real.
  static const ativo = kIsWeb && kDebugMode &&
      bool.fromEnvironment('FACE_WEB_TEST', defaultValue: true);
  static const foto = 'assets/test/rosto-teste.png';
}
