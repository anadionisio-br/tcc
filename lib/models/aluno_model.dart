class AlunoModel {
  final int idAluno;
  final String nome;
  String status;

  AlunoModel({
    required this.idAluno,
    required this.nome,
    this.status = 'Ausente',
  });

  factory AlunoModel.fromJson(Map<String, dynamic> json) {
    // Normaliza o status vindo do banco/API
    final statusRaw = (json['status'] ?? '').toString().trim().toLowerCase();
    
    String statusFormatado = 'Ausente';
    if (statusRaw == 'presente') {
      statusFormatado = 'Presente';
    } else if (statusRaw == 'ausente' || statusRaw == 'falta') {
      statusFormatado = 'Ausente';
    } else if (json['status'] != null && json['status'].toString().isNotEmpty) {
      // Caso a API retorne algo como 'Presente' com P maiúsculo
      statusFormatado = json['status'].toString();
    }

    return AlunoModel(
      idAluno: int.tryParse(
            (json['id_aluno'] ?? json['idAluno'] ?? json['id'] ?? 0).toString(),
          ) ??
          0,
      nome: json['nome_aluno'] ?? json['nome'] ?? 'Aluno sem nome',
      status: statusFormatado,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_aluno': idAluno,
      'nome_aluno': nome,
      'status': status,
    };
  }
}