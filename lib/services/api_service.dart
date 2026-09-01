import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/turma_model.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://10.141.130.70:8000/api";
    } else {
      return "http://10.0.2.2:8000/api";
    }
  }

  static const Map<String, String> defaultHeaders = {
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  // 1. Login Geral do Professor/Totem
  Future<Map<String, dynamic>> loginProfessor(String email, String senha) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: defaultHeaders,
      body: jsonEncode({
        "email": email,
        "password": senha,
        "role": "professor",
      }),
    );

    return jsonDecode(response.body);
  }

  // 2. Busca todas as turmas para o professor escolher no tablet
  Future<List<Turma>> listarTurmas() async {
    final response = await http.get(
      Uri.parse("$baseUrl/turmas"),
      headers: defaultHeaders,
    );

    if (response.statusCode == 200) {
      final List<dynamic> dados = jsonDecode(response.body);
      return dados.map((json) => Turma.fromJson(json)).toList();
    } else {
      throw Exception("Erro ao buscar turmas: ${response.statusCode}");
    }
  }

  // 3. Lista os alunos da turma selecionada para o totem
  Future<List<dynamic>> listarAlunosPorTurma(int idTurma) async {
    final response = await http.get(
      Uri.parse("$baseUrl/turmas/$idTurma/alunos"),
      headers: defaultHeaders,
    );

    if (response.statusCode == 200) {
      final dados = jsonDecode(response.body);
      return dados["alunos"] ?? [];
    } else {
      throw Exception("Erro ao buscar alunos da turma: ${response.statusCode}");
    }
  }

  // 4. Envia o reconhecimento de presença (Facial ou Manual no Totem)
  Future<void> registrarPresencaFacial(int idTurma, int idAluno) async {
    final response = await http.post(
      Uri.parse("$baseUrl/frequencia/reconhecimento"),
      headers: defaultHeaders,
      body: jsonEncode({
        "id_turma": idTurma,
        "id_aluno": idAluno,
        "status": "presente",
        "data_hora": DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Erro ao registrar presença: ${response.statusCode}");
    }
  }

  // Registra a frequência completa da turma de uma só vez
Future<bool> registrarFrequenciaTurma({
  required int idTurma,
  required List<Map<String, dynamic>> frequencias,
}) async {
  final response = await http.post(
    Uri.parse("$baseUrl/frequencia"),
    headers: defaultHeaders,
    body: jsonEncode({
      "id_turma": idTurma,
      "frequencias": frequencias, // Ex: [{"id_aluno": 1, "status": "presente"}]
    }),
  );

  return response.statusCode == 200 || response.statusCode == 201;
}
}