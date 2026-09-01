import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../models/aluno_model.dart';

class FrequenciaController extends ChangeNotifier {
  // Configuração base do Dio
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8000/api'));

  List<AlunoModel> alunos = [];
  bool carregando = false;
  DateTime dataSelecionada = DateTime.now();
  int turmaSelecionada = 1;

  String get dataFormatada => DateFormat('yyyy-MM-dd').format(dataSelecionada);

  // Contadores inteligentes atualizados em tempo real
  int get totalAlunos => alunos.length;
  int get presentes => alunos.where((a) => a.status == 'Presente').length;
  int get totalAusentes => alunos.where((a) => a.status == 'Falta' || a.status == 'Ausente').length;
  double get aproveitamento => totalAlunos > 0 ? (presentes / totalAlunos) * 100 : 100.0;

  // Busca a chamada usando a turma selecionada no estado atual
  Future<void> buscarChamada() async {
    carregando = true;
    notifyListeners();

    try {
      final response = await _dio.get('/frequencia', queryParameters: {
        'id_turma': turmaSelecionada,
        'data': dataFormatada,
      });

      if (response.statusCode == 200) {
        List dados = response.data['alunos'] ?? [];
        alunos = dados.map((json) => AlunoModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("Erro ao conectar ao Laravel: $e");

      // MOCK/TESTE LOCAL: Se a API Laravel estiver desligada, cria alunos simulados
      if (alunos.isEmpty) {
        alunos = [
          AlunoModel(idAluno: 1001, nome: "Ana Beatriz Nogueira", status: "Falta"),
          AlunoModel(idAluno: 1002, nome: "Carlos Eduardo Lima", status: "Falta"),
          AlunoModel(idAluno: 1003, nome: "Gabriel Henrique Santos", status: "Falta"),
          AlunoModel(idAluno: 1004, nome: "Julia Maria Souza", status: "Falta"),
        ];
      }
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  // 🚀 Suporte à navegação por argumento (TotemFacialPage)
  Future<void> buscarChamadaPorTurma(int idTurma) async {
    turmaSelecionada = idTurma;
    await buscarChamada();
  }

  // Registra a presença capturada pelo Totem Facial
  Future<bool> registrarPresencaFacial(int idAluno) async {
    // 1. Atualiza localmente no Flutter imediatamente para dar resposta rápida na tela do Totem
    final idx = alunos.indexWhere((a) => a.idAluno == idAluno);
    if (idx != -1) {
      alunos[idx].status = 'Presente';
      notifyListeners();
    }

    // 2. Envia a alteração em segundo plano para o Laravel via POST /api/frequencia
    try {
      final response = await _dio.post('/frequencia', data: {
        'id_aluno': idAluno,
        'id_turma': turmaSelecionada,
        'data': dataFormatada,
        'status': 'Presente',
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Presença do aluno $idAluno salva no Laravel com sucesso!");
        return true;
      }
    } catch (e) {
      debugPrint("Erro ao salvar presença no Laravel: $e");
    }
    return false;
  }

  // Ação de clique manual (caso o professor queira alterar na mão)
  void alternarStatus(int idAluno) {
    final idx = alunos.indexWhere((a) => a.idAluno == idAluno);
    if (idx != -1) {
      if (alunos[idx].status == 'Presente') {
        alunos[idx].status = 'Falta';
      } else {
        alunos[idx].status = 'Presente';
      }
      notifyListeners();
    }
  }

  void mudarData(DateTime novaData) {
    dataSelecionada = novaData;
    buscarChamada();
  }

  void mudarTurma(int idTurma) {
    turmaSelecionada = idTurma;
    buscarChamada();
  }
}