class AlunoModel {
  final int idAluno;
  final String nome;
  String status;

  AlunoModel({
    required this.idAluno,
    required this.nome,
    required this.status,
  });

  factory AlunoModel.fromJson(Map<String, dynamic> json) {
    return AlunoModel(
      idAluno: json['id_aluno'] ?? 0,
      nome: json['nome'] ?? '',
      status: json['status'] ?? 'Presente',
    );
  }
}