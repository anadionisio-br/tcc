import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../controllers/frequencia_controller.dart';
import 'totem_facial_page.dart';

class FrequenciaPage extends StatefulWidget {
  const FrequenciaPage({Key? key}) : super(key: key);

  @override
  State<FrequenciaPage> createState() => _FrequenciaPageState();
}

class _FrequenciaPageState extends State<FrequenciaPage> {
  @override
  void initState() {
    super.initState();
    // Dispara a busca dos dados assim que a tela é montada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FrequenciaController>().buscarChamada();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FrequenciaController>();

    // Exibe indicador de progresso enquanto os dados são carregados do controller
    if (controller.carregando) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(SifeTheme.primaryRed),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SifeTheme.bgLight,
      
      // --- BOTÃO FLUTUANTE PARA O MODO TOTEM (BATEDOR DE PONTO FACIAL) ---
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SifeTheme.primaryRed,
        icon: const FaIcon(FontAwesomeIcons.expand, color: Colors.white, size: 16),
        label: const Text(
          'Ativar Modo Totem', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TotemFacialPage()),
          );
        },
      ),

      // --- CORPO DA TELA ---
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. CARD DE FILTROS (TURMA E DATA)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SifeTheme.borderColor),
                boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20)],
              ),
              child: Row(
                children: [
                  // Seletor de Turma
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TURMA SELECIONADA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        DropdownButton<int>(
                          value: controller.turmaSelecionada,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('8º Ano B - Matutino', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                            DropdownMenuItem(value: 2, child: Text('9º Ano A - Matutino', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                          ],
                          onChanged: (val) => controller.mudarTurma(val!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Calendário / Seletor de Data
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: controller.dataSelecionada,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) controller.mudarData(picked);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              FaIcon(FontAwesomeIcons.calendarDays, size: 10, color: SifeTheme.primaryRed),
                              SizedBox(width: 4),
                              Text('DATA DA CHAMADA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(controller.dataFormatada, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. INDICADORES E ESTATÍSTICAS DO TOPO (DINÂMICOS)
            Row(
              children: [
                _buildStatCard("Total Alunos", controller.totalAlunos.toString(), SifeTheme.textDark),
                _buildStatCard("Presentes", controller.presentes.toString(), SifeTheme.btnPresenteText),
                _buildStatCard("Ausentes", controller.totalAusentes.toString(), SifeTheme.btnAusenteText),
                _buildStatCard("Aproveitamento", "${controller.aproveitamento.toStringAsFixed(0)}%", SifeTheme.textDark, showProgress: true),
              ],
            ),
            const SizedBox(height: 16),

            // 3. TABELA / LISTAGEM DOS ALUNOS
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SifeTheme.borderColor),
                ),
                child: Column(
                  children: [
                    // Cabeçalho da Lista
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: SifeTheme.bgLight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('IDENTIFICAÇÃO DO ALUNO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text('AÇÃO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                    ),
                    
                    // Construtor das Linhas de Alunos
                    Expanded(
                      child: ListView.builder(
                        itemCount: controller.alunos.length,
                        itemBuilder: (context, index) {
                          final aluno = controller.alunos[index];
                          bool isPresente = aluno.status == 'Presente';

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: SifeTheme.borderColor)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Foto e Detalhes do Aluno
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        "https://ui-avatars.com/api/?name=${Uri.encodeComponent(aluno.nome)}&background=E3F2FD&color=1565C0",
                                        width: 40,
                                        height: 40,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(aluno.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text('Mat: ${aluno.idAluno}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                      ],
                                    )
                                  ],
                                ),
                                
                                // Botão Clicável Interativo para Alternar Status
                                InkWell(
                                  onTap: () => controller.alternarStatus(aluno.idAluno),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    width: 100,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isPresente ? SifeTheme.btnPresenteBg : SifeTheme.btnAusenteBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isPresente ? SifeTheme.btnPresenteBorder : SifeTheme.btnAusenteBorder),
                                    ),
                                    child: Text(
                                      isPresente ? 'Presente' : 'Ausente',
                                      style: TextStyle(
                                        color: isPresente ? SifeTheme.btnPresenteText : SifeTheme.btnAusenteText,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Card Auxiliar para os contadores superiores
  Widget _buildStatCard(String title, String value, Color textColor, {bool showProgress = false}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: SifeTheme.borderColor),
        ),
        child: Column(
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
            if (showProgress) 
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 8, right: 8), 
                child: LinearProgressIndicator(value: 1.0, backgroundColor: SifeTheme.borderColor, color: Colors.green, minHeight: 4)
              ),
          ],
        ),
      ),
    );
  }
}