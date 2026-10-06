import 'package:flutter/foundation.dart';

/// Configuração central da API Laravel.
///
/// IMPORTANTE: troque apenas o valor de [_ipLocal] abaixo. Todo o resto do
/// app (login, turmas, frequência, totem facial, cadastro de rosto) usa
/// essa mesma constante, então você nunca mais precisa editar IP em mais
/// de um lugar.
///
/// Como descobrir o IP certo:
/// - Emulador Android rodando na mesma máquina que o `php artisan serve`:
///     use "10.0.2.2"
/// - Celular físico OU iOS Simulator, na MESMA rede Wi-Fi do computador
///   onde o Laravel está rodando:
///     use o IP local da máquina (ex: 192.168.0.15). Descubra com
///     `ipconfig` (Windows) ou `ifconfig` / `ip a` (Mac/Linux).
/// - Rodando em Flutter Web no mesmo computador do Laravel:
///     use "127.0.0.1" ou "localhost"
///
/// Lembre-se também de rodar o Laravel aceitando conexões de fora:
///   php artisan serve --host=0.0.0.0 --port=8000
class ApiConfig {
  ApiConfig._();

  // 🔧 TROQUE AQUI conforme o cenário de teste (ver instruções acima)
  static const String _ipLocal = '10.141.129.14';
  static const String _porta = '8000';

  /// Permite sobrescrever o IP em tempo de build sem editar código, ex:
  /// flutter run --dart-define=API_HOST=192.168.0.15
  static const String _hostOverride = String.fromEnvironment('API_HOST');

  static String get _host =>
      _hostOverride.isNotEmpty ? _hostOverride : _ipLocal;

  /// URL base usada por todas as chamadas HTTP do app.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://$_host:$_porta/api';
    }
    return 'http://$_host:$_porta/api';
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
