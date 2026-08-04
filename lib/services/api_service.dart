import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  static const String baseUrl = "http://10.0.2.2:8000/api";

  Future<Map<String, dynamic>> login(
      String email,
      String senha,
      String role) async {

    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {
        "Content-Type":"application/json"
      },
      body: jsonEncode({
        "email": email,
        "password": senha,
        "role": role
      }),
    );

    return jsonDecode(response.body);
  }

  Future<List<dynamic>> listarAlunos() async {

    final response = await http.get(
      Uri.parse("$baseUrl/alunos"),
    );

    final dados = jsonDecode(response.body);

    return dados["alunos"];
  }

  Future registrarFrequencia(
      int idAluno,
      String status) async {

    await http.post(
      Uri.parse("$baseUrl/frequencia"),
      headers: {
        "Content-Type":"application/json"
      },
      body: jsonEncode({

        "id_turma":1,

        "frequencias":[
          {
            "id_aluno":idAluno,
            "status":status
          }
        ]

      }),
    );
  }

}