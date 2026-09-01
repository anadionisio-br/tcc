import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../controllers/frequencia_controller.dart';
import 'totem_facial_page.dart';
import 'cadastro_rosto_page.dart';

class FrequenciaPage extends StatefulWidget {
  const FrequenciaPage({Key? key}) : super(key: key);

  @override
  State<FrequenciaPage> createState() => _FrequenciaPageState();
}

class _FrequenciaPageState extends State<FrequenciaPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FrequenciaController>().buscarChamada();
    });
  }

  // Função auxiliar para gerar iniciais para o avatar
  String _getIniciais(String nome) {
    if (nome.trim().isEmpty) return '';
    List<String> partes = nome.trim().split(' ');
    if (partes.length == 1) {
      return partes[0].substring(0, partes[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  // Função para salvar toda a chamada no Laravel/Banco
  Future<void> _salvarChamadaLote(FrequenciaController controller) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Sincronizando chamada com o banco de dados...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    int sucessos = 0;
    for (var aluno in controller.alunos) {
      if (aluno.status == 'Presente') {
        bool ok = await controller.registrarPresencaFacial(aluno.idAluno);
        if (ok) sucessos++;
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF12B886),
        content: Text('Chamada salva no banco! ($sucessos presença(s) confirmada(s))'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FrequenciaController>();

    if (controller.carregando) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(SifeTheme.primaryRed),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),

      // Floating Action Button para Ativar Modo Totem
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SifeTheme.primaryRed,
        elevation: 4,
        icon: const FaIcon(FontAwesomeIcons.expand, color: Colors.white, size: 16),
        label: const Text(
          'Ativar Modo Totem',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TotemFacialPage(),
              settings: RouteSettings(
                arguments: {'id_turma': controller.turmaSelecionada},
              ),
            ),
          );
          // Recarrega os dados do banco ao fechar a tela de totem
          controller.buscarChamada();
        },
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TOP HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REGISTRO DE AULA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Frequência da Turma',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Botão Cadastrar Rosto (Ação secundária)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      icon: const FaIcon(FontAwesomeIcons.userPlus, size: 14, color: SifeTheme.primaryRed),
                      label: const Text(
                        'Cadastrar Rosto',
                        style: TextStyle(color: SifeTheme.primaryRed, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final ok = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CadastroRostoPage()),
                        );
                        if (ok == true) {
                          controller.buscarChamada();
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    // Botão SALVAR CHAMADA CONECTADO AO BANCO
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD92D20), // Vermelho vibrante
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      icon: const FaIcon(FontAwesomeIcons.cloudArrowUp, size: 16, color: Colors.white),
                      label: const Text(
                        'SALVAR CHAMADA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      onPressed: () => _salvarChamadaLote(controller),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- 1. CARD DE FILTROS & BOTOES DE AÇÃO EM MASSA ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Dropdown Turma
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TURMA SELECIONADA',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: controller.turmaSelecionada,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('Turma A - 1º Ano (Manhã)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                                DropdownMenuItem(value: 2, child: Text('Turma B - 2º Ano (Manhã)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                              ],
                              onChanged: (val) {
                                if (val != null) controller.mudarTurma(val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Seletor de Data
                  Expanded(
                    flex: 2,
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
                          Text(
                            'DATA',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  controller.dataFormatada,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Botões Marcar Todos
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFFD92D20)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        for (var aluno in controller.alunos) {
                          if (aluno.status != 'Presente') {
                            controller.alternarStatus(aluno.idAluno);
                          }
                        }
                      },
                      child: const Text(
                        'Todos Presentes',
                        style: TextStyle(color: Color(0xFFD92D20), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        for (var aluno in controller.alunos) {
                          if (aluno.status == 'Presente') {
                            controller.alternarStatus(aluno.idAluno);
                          }
                        }
                      },
                      child: Text(
                        'Todos Ausentes',
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 2. CARDS DE METRICAS ---
            Row(
              children: [
                _buildStatCard('TOTAL ALUNOS', controller.totalAlunos.toString(), const Color(0xFF1E293B)),
                const SizedBox(width: 16),
                _buildStatCard('PRESENTES', controller.presentes.toString(), const Color(0xFF16A34A)),
                const SizedBox(width: 16),
                _buildStatCard('AUSENTES', controller.totalAusentes.toString(), const Color(0xFFD92D20)),
                const SizedBox(width: 16),
                _buildStatCard(
                  'APROVEITAMENTO',
                  '${controller.aproveitamento.toStringAsFixed(0)}%',
                  const Color(0xFF1E293B),
                  showProgress: true,
                  progressValue: controller.aproveitamento / 100,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- 3. TABELA / LISTA DE ALUNOS ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Cabeçalho da Lista
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ESTUDANTE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.5),
                        ),
                        Text(
                          'PRESENÇA',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // Lista de Alunos
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.alunos.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final aluno = controller.alunos[index];
                      bool isPresente = aluno.status == 'Presente';

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Info do Aluno (Avatar + Nome + Matrícula)
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFFE0F2FE),
                                  child: Text(
                                    _getIniciais(aluno.nome),
                                    style: const TextStyle(
                                      color: Color(0xFF0284C7),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      aluno.nome,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Mat: ${aluno.idAluno}',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Botão Indicador de Presença
                            InkWell(
                              onTap: () {
                                controller.alternarStatus(aluno.idAluno);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isPresente ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isPresente ? const Color(0xFFA5D6A7) : const Color(0xFFFFCDD2),
                                  ),
                                ),
                                child: Text(
                                  isPresente ? 'Presente' : 'Ausente',
                                  style: TextStyle(
                                    color: isPresente ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Card Auxiliar de Métricas Superior
  Widget _buildStatCard(String title, String value, Color valueColor, {bool showProgress = false, double progressValue = 0.0}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
            ),
            if (showProgress) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFF16A34A),
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}