import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/turma_model.dart';

/// Ponto único de acesso à API Laravel.
///
/// Antes existiam 3 formas diferentes de fazer requisições no projeto
/// (Dio no controller, Dio na tela de cadastro de rosto, http no
/// ApiService antigo) cada uma com sua própria baseUrl. Isso causava
/// comportamento inconsistente e dificultava achar o motivo real de um
/// erro de conexão. Agora só existe este serviço.
class ApiService {
  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: ApiConfig.defaultHeaders,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          debugPrint('--> [${options.method}] ${options.baseUrl}${options.path}');
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          debugPrint(
            '--> ERRO DE REDE: ${e.message} | '
            'status=${e.response?.statusCode} | body=${e.response?.data}',
          );
          return handler.next(e);
        },
      ),
    );
  }

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  String? _token;

  /// Expõe o Dio configurado para telas/controllers que precisam de
  /// chamadas mais específicas (ex: FrequenciaController).
  Dio get client => _dio;

  void setToken(String? token) => _token = token;

  // ---------------------------------------------------------------------
  // 1. LOGIN
  // ---------------------------------------------------------------------
  /// Faz login contra o Laravel. Lança [ApiException] em caso de erro,
  /// com a mensagem que o backend retornou (quando disponível).
  Future<Map<String, dynamic>> loginProfessor(String email, String senha) async {
    try {
      final response = await _dio.post('/login', data: {
        'email': email,
        'password': senha,
        'role': 'professor',
      });

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final token = data['token'] ?? data['access_token'];
        if (token != null) setToken(token.toString());
        return data;
      }
      return {'success': true, 'raw': data};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, contexto: 'login');
    }
  }

  // ---------------------------------------------------------------------
  // 2. TURMAS
  // ---------------------------------------------------------------------
  Future<List<Turma>> listarTurmas() async {
    try {
      final response = await _dio.get('/turmas');
      final data = response.data;

      List dados;
      if (data is List) {
        dados = data;
      } else if (data is Map) {
        dados = data['turmas'] ?? data['data'] ?? data['result'] ?? data['rows'] ?? [];
      } else {
        dados = [];
      }

      return dados
          .map((json) => Turma.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, contexto: 'listar turmas');
    }
  }

  // ---------------------------------------------------------------------
  // 3. ALUNOS DE UMA TURMA
  // ---------------------------------------------------------------------
  Future<List<dynamic>> listarAlunosPorTurma(int idTurma) async {
    try {
      final response = await _dio.get('/turmas/$idTurma/alunos');
      final data = response.data;
      if (data is Map) return data['alunos'] ?? [];
      if (data is List) return data;
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, contexto: 'listar alunos da turma');
    }
  }

  // ---------------------------------------------------------------------
  // 4. REGISTRAR PRESENÇA (Totem / reconhecimento facial)
  // ---------------------------------------------------------------------
  Future<bool> registrarPresencaFacial({
    required int idTurma,
    required int idAluno,
    required String data,
    String status = 'Presente',
  }) async {
    try {
      final response = await _dio.post('/frequencia', data: {
        'id_aluno': idAluno,
        'aluno_id': idAluno,
        'id_turma': idTurma,
        'turma_id': idTurma,
        'data': data,
        'status': status,
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, contexto: 'registrar presença');
    }
  }

  // ---------------------------------------------------------------------
  // 5. REGISTRAR CHAMADA COMPLETA DE UMA VEZ (lote)
  // ---------------------------------------------------------------------
  Future<bool> registrarFrequenciaTurma({
    required int idTurma,
    required List<Map<String, dynamic>> frequencias,
  }) async {
    try {
      final response = await _dio.post('/frequencia', data: {
        'id_turma': idTurma,
        'frequencias': frequencias,
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, contexto: 'registrar chamada em lote');
    }
  }

  // ---------------------------------------------------------------------
  // 6. BUSCAR CHAMADA (lista de alunos + status do dia)
  // ---------------------------------------------------------------------
  Future<dynamic> buscarChamada({required int idTurma, required String data}) async {
    try {
      final response = await _dio.get('/frequencia', queryParameters: {
        'turma_id': idTurma,
        'id_turma': idTurma,
        'data': data,
      });
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, contexto: 'buscar chamada');
    }
  }

  Future<bool> cadastrarRosto({
  required int idAluno,
  required List<double> embedding,
}) async {
  try {
    final response = await _dio.post(
      '/reconhecimento/cadastrar',
      data: {
        'id_aluno': idAluno,
        'embedding': embedding,
      },
    );

    return response.statusCode == 200 &&
        response.data['success'] == true;
  } on DioException catch (e) {
    throw ApiException.fromDioException(
      e,
      contexto: 'cadastrar rosto',
    );
  }
}

Future<Map<String, dynamic>> reconhecerRosto({
  required List<double> embedding,
  int? idTurma,
}) async {
  try {
    final response = await _dio.post(
      '/reconhecimento/reconhecer',
      data: {
        'embedding': embedding,
        if (idTurma != null)
          'id_turma': idTurma,
      },
    );

    if (response.data is! Map) {
      throw ApiException(
        mensagemAmigavel:
            'Resposta inválida do reconhecimento facial.',
        contexto: 'reconhecer rosto',
        statusCode: response.statusCode,
        detalhesBackend: response.data,
      );
    }

    return Map<String, dynamic>.from(
      response.data,
    );
  } on DioException catch (e) {
    throw ApiException.fromDioException(
      e,
      contexto: 'reconhecer rosto',
    );
  }
}
  // ---------------------------------------------------------------------
  // 7. CADASTRO DE ALUNO COM FOTO (biometria facial)
  // ---------------------------------------------------------------------
Future<bool> cadastrarAlunoComFoto({
  required int idAluno,
  required String nome,
  required String caminhoFoto,
}) async {
  try {
    final formData = FormData.fromMap({
      'id_aluno': idAluno,
      'nome': nome,
      'foto': await MultipartFile.fromFile(
        caminhoFoto,
        filename: 'rosto_aluno.jpg',
      ),
    });

    final response = await _dio.post(
      '/cadastrar-com-foto',
      data: formData,
    );

    return response.statusCode == 200 ||
        response.statusCode == 201;
  } on DioException catch (e) {
    throw ApiException.fromDioException(
      e,
      contexto: 'cadastrar aluno com foto',
    );
  }
}
}

/// Exceção padronizada, com mensagem amigável pronta para exibir num
/// SnackBar, além dos detalhes técnicos para debug/log.
class ApiException implements Exception {
  final String mensagemAmigavel;
  final String contexto;
  final int? statusCode;
  final dynamic detalhesBackend;

  ApiException({
    required this.mensagemAmigavel,
    required this.contexto,
    this.statusCode,
    this.detalhesBackend,
  });

  factory ApiException.fromDioException(DioException e, {required String contexto}) {
    final status = e.response?.statusCode;
    String msg;

    // Mensagem enviada pelo Laravel (ex.: "Este usuário não é um professor.")
    final corpo = e.response?.data;
    final msgBackend = (corpo is Map && corpo['message'] is String)
        ? corpo['message'] as String
        : null;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        msg = 'O servidor demorou para responder. Verifique se a API está no ar e '
            'se o celular está na mesma rede Wi-Fi do servidor.';
        break;
      case DioExceptionType.connectionError:
        msg = 'Não foi possível conectar à API. Verifique o IP configurado em '
            'api_config.dart, se o Laravel está rodando com --host=0.0.0.0, e se '
            'não há bloqueio de tráfego HTTP (cleartext) no Android/iOS.';
        break;
      case DioExceptionType.badResponse:
        if (msgBackend != null &&
            (status == 401 || status == 403 || status == 422)) {
          msg = msgBackend;
        } else if (status == 401 || status == 403) {
          msg = 'E-mail ou senha inválidos.';
        } else if (status == 404) {
          msg = 'Rota não encontrada na API (verifique as rotas do Laravel).';
        } else if (status != null && status >= 500) {
          msg = 'Erro interno no servidor Laravel (verifique os logs em storage/logs).';
        } else {
          msg = 'A API retornou um erro (status $status).';
        }
        break;
      default:
        msg = 'Erro inesperado de rede: ${e.message}';
    }

    return ApiException(
      mensagemAmigavel: msg,
      contexto: contexto,
      statusCode: status,
      detalhesBackend: e.response?.data,
    );
  }

  

  @override
  String toString() => 'ApiException[$contexto | status=$statusCode]: $mensagemAmigavel';
}
