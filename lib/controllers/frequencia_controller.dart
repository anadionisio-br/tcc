import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/aluno_model.dart';
import '../services/api_service.dart';

class FrequenciaController extends ChangeNotifier {
  final Dio _dio = ApiService().client;

  // ============================================================
  // DADOS
  // ============================================================

  List<AlunoModel> alunos = [];
  List<Map<String, dynamic>> turmas = [];

  bool carregando = false;
  bool carregandoTurmas = false;

  String? erroTurmas;
  String? erroChamada;

  DateTime dataSelecionada = _somenteData(DateTime.now());

  int? turmaSelecionada;

  // Evita várias chamadas simultâneas.
  bool _buscandoChamada = false;

  // ============================================================
  // GETTERS
  // ============================================================

  String get dataFormatada {
    return DateFormat('yyyy-MM-dd').format(dataSelecionada);
  }

  int get totalAlunos => alunos.length;

  int get presentes {
    return alunos.where((a) => a.status == 'Presente').length;
  }

  int get totalAusentes {
    return alunos
        .where((a) => a.status == 'Falta' || a.status == 'Ausente')
        .length;
  }

  double get aproveitamento {
    if (totalAlunos == 0) {
      return 0;
    }

    return (presentes / totalAlunos) * 100;
  }

  bool get dataEhFutura {
    final hoje = _somenteData(DateTime.now());
    return dataSelecionada.isAfter(hoje);
  }

  // ============================================================
  // UTILITÁRIOS
  // ============================================================

  static DateTime _somenteData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  int? _converterId(dynamic valor) {
    if (valor == null) {
      return null;
    }

    if (valor is int) {
      return valor;
    }

    return int.tryParse(valor.toString());
  }

  List<dynamic> _extrairLista(dynamic responseData) {
    if (responseData is List) {
      return responseData;
    }

    if (responseData is Map) {
      final map = Map<String, dynamic>.from(responseData);

      if (map['data'] is List) {
        return map['data'];
      }

      if (map['alunos'] is List) {
        return map['alunos'];
      }

      if (map['result'] is List) {
        return map['result'];
      }

      if (map['rows'] is List) {
        return map['rows'];
      }

      if (map['frequencia'] is List) {
        return map['frequencia'];
      }

      if (map['frequencias'] is List) {
        return map['frequencias'];
      }
    }

    return [];
  }

  // ============================================================
  // TURMAS
  // ============================================================

  Future<void> buscarTurmasDoBanco() async {
    await buscarTurmas();
  }

  Future<void> buscarTurmas() async {
    if (carregandoTurmas) {
      return;
    }

    carregandoTurmas = true;
    erroTurmas = null;

    notifyListeners();

    try {
      debugPrint('========================================');
      debugPrint('BUSCANDO TURMAS');
      debugPrint('URL: ${_dio.options.baseUrl}/turmas');
      debugPrint('========================================');

      final response = await _dio.get('/turmas');

      debugPrint('STATUS TURMAS: ${response.statusCode}');

      if (response.statusCode != 200) {
        erroTurmas = 'Não foi possível carregar as turmas.';
        turmas = [];
        return;
      }

      final dados = _extrairLista(response.data);

      final novasTurmas = <Map<String, dynamic>>[];
      final idsTurmas = <int>{};

      for (final item in dados) {
        if (item is! Map) {
          continue;
        }

        final map = Map<String, dynamic>.from(item);

        final idTurma = _converterId(
          map['id_turma'] ??
              map['id'] ??
              map['idTurma'],
        );

        if (idTurma == null || idTurma <= 0) {
          continue;
        }

        if (idsTurmas.contains(idTurma)) {
          continue;
        }

        idsTurmas.add(idTurma);

        novasTurmas.add({
          'id_turma': idTurma,
          'nome_turma':
              (map['nome_turma'] ??
                      map['nome'] ??
                      map['turma'] ??
                      map['descricao'] ??
                      'Turma')
                  .toString(),
          'serie':
              (map['serie'] ?? map['ano'] ?? '').toString(),
          'periodo':
              (map['periodo'] ?? map['turno'] ?? '').toString(),
          'sala':
              (map['sala'] ?? map['numero_sala'] ?? '').toString(),
          'total_alunos':
              _converterId(
                    map['total_alunos'] ??
                        map['alunos_count'] ??
                        map['totalAlunos'] ??
                        0,
                  ) ??
                  0,
        });
      }

      turmas = novasTurmas;

      final turmaExiste =
          turmaSelecionada != null &&
          turmas.any(
            (turma) =>
                turma['id_turma'] == turmaSelecionada,
          );

      if (!turmaExiste) {
        if (turmas.isNotEmpty) {
          turmaSelecionada =
              turmas.first['id_turma'] as int;
        } else {
          turmaSelecionada = null;
          alunos = [];
        }
      }
    } on DioException catch (e) {
      _logErroDio(
        e,
        contexto: 'buscar turmas',
      );

      final erro = ApiException.fromDioException(
        e,
        contexto: 'buscar turmas',
      );

      erroTurmas = erro.mensagemAmigavel;
      turmas = [];
    } catch (e, stackTrace) {
      debugPrint('ERRO AO BUSCAR TURMAS: $e');
      debugPrint('STACK: $stackTrace');

      erroTurmas =
          'Erro inesperado ao buscar turmas.';
      turmas = [];
    } finally {
      carregandoTurmas = false;
      notifyListeners();
    }

    if (turmaSelecionada != null &&
        turmaSelecionada! > 0) {
      await buscarChamada();
    }
  }

 // ============================================================
  // BUSCAR CHAMADA
  // ============================================================

  Future<void> buscarChamada() async {
    if (turmaSelecionada == null || turmaSelecionada! <= 0) return;

    carregando = true;
    erroChamada = null;
    notifyListeners();

    try {
      // Uma única chamada: o Laravel já devolve os alunos da turma
      // com o status (Presente/Ausente) do dia escolhido.
      final resp = await _dio.get(
        '/frequencia',
        queryParameters: {
          'id_turma': turmaSelecionada,
          'data': dataFormatada,
        },
      );

      final lista = _extrairLista(resp.data);

      alunos = lista
          .whereType<Map>()
          .map((e) => AlunoModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      debugPrint('ALUNOS ENCONTRADOS: ${alunos.length}');
    } on DioException catch (e) {
      _logErroDio(e, contexto: 'buscar chamada');
      erroChamada =
          ApiException.fromDioException(e, contexto: 'buscar chamada')
              .mensagemAmigavel;
      alunos = [];
    } catch (e, stack) {
      debugPrint('ERRO AO BUSCAR CHAMADA: $e\n$stack');
      erroChamada = 'Erro inesperado ao buscar a chamada.';
      alunos = [];
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  // ============================================================
  // BUSCAR CHAMADA POR TURMA
  // ============================================================

  Future<void> buscarChamadaPorTurma(
    int idTurma,
  ) async {
    if (idTurma <= 0) {
      debugPrint(
        'ID DA TURMA INVÁLIDO: $idTurma',
      );
      return;
    }

    debugPrint(
      'BUSCAR CHAMADA POR TURMA: $idTurma',
    );

    turmaSelecionada = idTurma;

    await buscarChamada();
  }

  // ============================================================
  // TROCAR TURMA
  // ============================================================

  Future<void> mudarTurma(int idTurma) async {
    if (idTurma <= 0) {
      return;
    }

    if (turmaSelecionada == idTurma) {
      return;
    }

    debugPrint(
      'MUDANDO TURMA: $idTurma',
    );

    turmaSelecionada = idTurma;

    alunos = [];

    notifyListeners();

    await buscarChamada();
  }

  // ============================================================
  // TROCAR DATA
  // ============================================================

  Future<void> mudarData(
    DateTime novaData,
  ) async {
    final data = _somenteData(novaData);
    final hoje = _somenteData(DateTime.now());

    if (data.isAfter(hoje)) {
      debugPrint(
        'DATA FUTURA BLOQUEADA: $data',
      );
      return;
    }

    if (data.year == dataSelecionada.year &&
        data.month == dataSelecionada.month &&
        data.day == dataSelecionada.day) {
      return;
    }

    debugPrint('========================================');
    debugPrint('ALTERANDO DATA');
    debugPrint(
      'DATA ANTIGA: $dataFormatada',
    );
    debugPrint(
      'NOVA DATA: '
      '${DateFormat('yyyy-MM-dd').format(data)}',
    );
    debugPrint(
      'TURMA: $turmaSelecionada',
    );
    debugPrint('========================================');

    dataSelecionada = data;

    alunos = [];

    notifyListeners();

    await buscarChamada();
  }

  // ============================================================
  // REGISTRAR PRESENÇA FACIAL
  // ============================================================

  Future<bool> registrarPresencaFacial(int idAluno) async {
  if (turmaSelecionada == null || turmaSelecionada! <= 0) {
    debugPrint('ERRO: turma não selecionada');
    return false;
  }

  if (dataEhFutura) {
    debugPrint('ERRO: data futura');
    return false;
  }

  try {
    final dados = {
      'id_aluno': idAluno,
      'id_turma': turmaSelecionada,
      'data': dataFormatada,
      'status': 'Presente',
    };

    debugPrint('====================================');
    debugPrint('POST /frequencia');
    debugPrint('ALUNO: $idAluno');
    debugPrint('TURMA: $turmaSelecionada');
    debugPrint('DATA: $dataFormatada');
    debugPrint('BODY: $dados');

    final response = await _dio.post(
      '/frequencia',
      data: dados,
    );

    debugPrint('STATUS: ${response.statusCode}');
    debugPrint('RESPOSTA: ${response.data}');
    debugPrint('====================================');

    return response.statusCode == 200 ||
        response.statusCode == 201;
  } on DioException catch (e) {
    debugPrint('====================================');
    debugPrint('ERRO POST /frequencia');
    debugPrint('URL: ${e.requestOptions.uri}');
    debugPrint('STATUS: ${e.response?.statusCode}');
    debugPrint('RESPOSTA: ${e.response?.data}');
    debugPrint('BODY: ${e.requestOptions.data}');
    debugPrint('MENSAGEM: ${e.message}');
    debugPrint('====================================');

    return false;
  } catch (e, stackTrace) {
    debugPrint('ERRO: $e');
    debugPrint('STACK: $stackTrace');
    return false;
  }
}


Future<bool> alternarStatus(int idAluno) async {
  if (turmaSelecionada == null ||
      turmaSelecionada! <= 0) {
    return false;
  }

  if (dataEhFutura) {
    return false;
  }

  final index = alunos.indexWhere(
    (aluno) => aluno.idAluno == idAluno,
  );

  if (index == -1) {
    return false;
  }

  final aluno = alunos[index];

  aluno.status =
      aluno.status == 'Presente'
          ? 'Ausente'
          : 'Presente';

  notifyListeners();

  return true;
}

bool salvandoChamada = false;

Future<bool> salvarChamada() async {
  if (turmaSelecionada == null ||
      turmaSelecionada! <= 0) {
    return false;
  }

  if (dataEhFutura) {
    return false;
  }

  if (alunos.isEmpty) {
    return false;
  }

  if (salvandoChamada) {
    return false;
  }

  salvandoChamada = true;
  notifyListeners();

  try {
    final frequencias = alunos.map((aluno) {
      return {
        'id_aluno': aluno.idAluno,
        'status': aluno.status,
      };
    }).toList();

    debugPrint('========================================');
    debugPrint('SALVANDO CHAMADA EM LOTE');
    debugPrint('TURMA: $turmaSelecionada');
    debugPrint('DATA: $dataFormatada');
    debugPrint('ALUNOS: ${frequencias.length}');
    debugPrint('========================================');

    final response = await _dio.post(
      '/frequencia',
      data: {
        'id_turma': turmaSelecionada,
        'data': dataFormatada,
        'frequencias': frequencias,
      },
    );

    debugPrint(
      'STATUS SALVAMENTO: ${response.statusCode}',
    );

    debugPrint(
      'RESPOSTA: ${response.data}',
    );

    return response.statusCode == 200 ||
        response.statusCode == 201;
  } on DioException catch (e) {
    _logErroDio(
      e,
      contexto: 'salvar chamada',
    );

    return false;
  } catch (e, stackTrace) {
    debugPrint(
      'ERRO AO SALVAR CHAMADA: $e',
    );

    debugPrint('$stackTrace');

    return false;
  } finally {
    salvandoChamada = false;
    notifyListeners();
  }
}
  // ============================================================
  // MARCAR TODOS PRESENTES
  // ============================================================

Future<int> marcarTodosPresentes() async {
  if (dataEhFutura) {
    return 0;
  }

  int alterados = 0;

  for (final aluno in alunos) {
    if (aluno.status != 'Presente') {
      aluno.status = 'Presente';
      alterados++;
    }
  }

  notifyListeners();

  return alterados;
}
  // ============================================================
  // MARCAR TODOS AUSENTES
  // ============================================================

Future<int> marcarTodosAusentes() async {
  if (dataEhFutura) {
    return 0;
  }

  int alterados = 0;

  for (final aluno in alunos) {
    if (aluno.status != 'Ausente') {
      aluno.status = 'Ausente';
      alterados++;
    }
  }

  notifyListeners();

  return alterados;
}
  // ============================================================
  // RECARREGAR
  // ============================================================

  Future<void> recarregarChamada() async {
    await buscarChamada();
  }

  // ============================================================
  // LOG DE ERRO
  // ============================================================

  void _logErroDio(
    DioException e, {
    required String contexto,
  }) {
    debugPrint('');
    debugPrint(
      '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!',
    );
    debugPrint(
      'ERRO DIO - $contexto',
    );
    debugPrint(
      '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!',
    );

    debugPrint(
      'TIPO: ${e.type}',
    );

    debugPrint(
      'MENSAGEM: ${e.message}',
    );

    debugPrint(
      'ERRO INTERNO: ${e.error}',
    );

    debugPrint(
      'STACK TRACE: ${e.stackTrace}',
    );

    debugPrint('');
    debugPrint('--------- REQUEST ---------');

    debugPrint(
      'URL: ${e.requestOptions.uri}',
    );

    debugPrint(
      'METHOD: ${e.requestOptions.method}',
    );

    debugPrint(
      'HEADERS: ${e.requestOptions.headers}',
    );

    debugPrint(
      'QUERY: ${e.requestOptions.queryParameters}',
    );

    debugPrint(
      'BODY: ${e.requestOptions.data}',
    );

    debugPrint('');
    debugPrint('--------- RESPONSE ---------');

    debugPrint(
      'STATUS: ${e.response?.statusCode}',
    );

    debugPrint(
      'STATUS MESSAGE: '
      '${e.response?.statusMessage}',
    );

    debugPrint(
      'HEADERS: ${e.response?.headers}',
    );

    debugPrint(
      'DATA: ${e.response?.data}',
    );

    debugPrint(
      '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!',
    );

    debugPrint('');
  }

  // Dentro da classe FrequenciaController:

// ============================================================
  // REGISTRAR AUSÊNCIA
  // ============================================================

  Future<bool> registrarAusencia(int idAluno) async {
  if (turmaSelecionada == null ||
      turmaSelecionada! <= 0) {
    return false;
  }

  if (dataEhFutura) {
    return false;
  }

  final idx = alunos.indexWhere(
    (a) => a.idAluno == idAluno,
  );

  if (idx == -1) {
    debugPrint(
      'ALUNO NÃO ENCONTRADO: $idAluno',
    );
    return false;
  }

  try {
    final dados = {
      'id_aluno': idAluno,
      'aluno_id': idAluno,
      'id_turma': turmaSelecionada,
      'turma_id': turmaSelecionada,
      'data': dataFormatada,
      'status': 'Ausente',
    };

    debugPrint(
      '========================================',
    );
    debugPrint(
      'SALVANDO AUSÊNCIA',
    );
    debugPrint(
      'ALUNO: $idAluno',
    );
    debugPrint(
      'TURMA: $turmaSelecionada',
    );
    debugPrint(
      'DATA: $dataFormatada',
    );
    debugPrint(
      'STATUS: Ausente',
    );
    debugPrint(
      '========================================',
    );

    final response = await _dio.post(
      '/frequencia',
      data: dados,
    );

    debugPrint(
      'STATUS POST: ${response.statusCode}',
    );

    debugPrint(
      'RESPOSTA POST: ${response.data}',
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      return true;
    }

    debugPrint(
      'ERRO: API retornou ${response.statusCode}',
    );

    return false;
  } on DioException catch (e) {
    _logErroDio(
      e,
      contexto: 'registrar ausência',
    );

    return false;
  } catch (e, stackTrace) {
    debugPrint(
      'ERRO AO REGISTRAR AUSÊNCIA: $e',
    );

    debugPrint(
      'STACK: $stackTrace',
    );

    return false;
  }
}

// ============================================================
// ALTERAR STATUS SOMENTE NA TELA
// ============================================================

void definirStatusLocal(
  int idAluno,
  String novoStatus,
) {
  final index = alunos.indexWhere(
    (aluno) => aluno.idAluno == idAluno,
  );

  if (index == -1) {
    return;
  }

  alunos[index].status = novoStatus;

  notifyListeners();
}
}
