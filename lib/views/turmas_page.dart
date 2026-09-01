import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../config/theme.dart';
import 'navigation_menu.dart';

class TurmasPage extends StatefulWidget {
  const TurmasPage({super.key});

  @override
  State<TurmasPage> createState() => _TurmasPageState();
}

class _TurmasPageState extends State<TurmasPage> {
  // Exemplo de lista de turmas (pode ser trocado pelos dados do seu banco)
  final List<Map<String, dynamic>> _turmas = [
    {
      'id': 1,
      'nome': '8º Ano B',
      'turno': 'Matutino',
      'sala': 'Sala 04',
      'alunos': 32,
    },
    {
      'id': 2,
      'nome': '9º Ano A',
      'turno': 'Vespertino',
      'sala': 'Sala 02',
      'alunos': 28,
    },
    {
      'id': 3,
      'nome': '7º Ano C',
      'turno': 'Matutino',
      'sala': 'Sala 08',
      'alunos': 30,
    },
  ];

  int? _turmaSelecionadaId;

  void _confirmarEAvancar(Map<String, dynamic> turma) {
    setState(() {
      _turmaSelecionadaId = turma['id'] as int;
    });

    // Navega para o menu principal com a turma selecionada
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const NavigationMenu(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SifeTheme.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Minhas Turmas',
          style: TextStyle(
            color: SifeTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecione uma turma',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: SifeTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Escolha a turma que deseja gerenciar nesta sessão:',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _turmas.length,
                  itemBuilder: (context, index) {
                    final turma = _turmas[index];
                    final isSelected = _turmaSelecionadaId == turma['id'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? SifeTheme.primaryRed
                              : SifeTheme.borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? SifeTheme.primaryRed
                                : SifeTheme.primaryRedSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: FaIcon(
                            FontAwesomeIcons.users,
                            size: 20,
                            color: isSelected
                                ? Colors.white
                                : SifeTheme.primaryRed,
                          ),
                        ),
                        title: Text(
                          turma['nome'].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: SifeTheme.textDark,
                          ),
                        ),
                        subtitle: Text(
                          '${turma['turno']} • ${turma['sala']} • ${turma['alunos']} Alunos',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: const FaIcon(
                          FontAwesomeIcons.chevronRight,
                          size: 14,
                          color: Colors.grey,
                        ),
                        onTap: () => _confirmarEAvancar(turma),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}