import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/theme.dart';

class AlunoPage extends StatelessWidget {
  const AlunoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SifeTheme.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Portal do Aluno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: SifeTheme.textDark)),
            Text('Carlos Eduardo Silva • Mat: 2026048', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- CARDS DE DESEMPENHO DO ALUNO ---
            Row(
              children: [
                _buildAlunoStatCard("Sua Frequência", "92%", Colors.green, FontAwesomeIcons.userCheck),
                _buildAlunoStatCard("Total Faltas", "4", SifeTheme.btnAusenteText, FontAwesomeIcons.userXmark),
                _buildAlunoStatCard("Status Geral", "Regular", SifeTheme.textDark, FontAwesomeIcons.circleCheck),
              ],
            ),
            const SizedBox(height: 16),

            // --- SEÇÃO: HISTÓRICO DE AUSÊNCIAS ---
            const Text('Histórico de Faltas Recentes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: SifeTheme.textDark)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SifeTheme.borderColor),
              ),
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildFaltaRow("22/06/2026", "Matemática", "Falta Justificada (Atestado)"),
                  _buildFaltaRow("15/06/2026", "História", "Falta Não Justificada"),
                  _buildFaltaRow("08/06/2026", "Geografia", "Falta Não Justificada"),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- BOTÃO DE ENVIAR ATESTADO ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SifeTheme.primaryRedSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SifeTheme.btnAusenteBorder),
              ),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.fileMedical, color: SifeTheme.primaryRed, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Faltou em alguma aula?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: SifeTheme.textDark)),
                        Text('Envie o comprovante ou atestado médico diretamente pelo app.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SifeTheme.primaryRed,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Abrindo câmera/galeria para upload...'), backgroundColor: SifeTheme.textDark),
                      );
                    },
                    child: const Text('Enviar', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAlunoStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SifeTheme.borderColor),
        ),
        child: Column(
          children: [
            FaIcon(icon, size: 16, color: color),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildFaltaRow(String data, String materia, String justificativa) {
    bool isJustificada = justificativa.contains("Justificada");
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SifeTheme.borderColor))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(materia, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(justificativa, style: TextStyle(color: isJustificada ? Colors.green : SifeTheme.btnAusenteText, fontSize: 12)),
            ],
          ),
          Text(data, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}