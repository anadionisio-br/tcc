import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../config/face_test_config.dart';
import '../controllers/frequencia_controller.dart';
import 'totem_facial_page.dart';
import 'cadastro_rosto_page.dart';

class FrequenciaPage extends StatefulWidget {
  const FrequenciaPage({Key? key}) : super(key: key);

  @override
  State<FrequenciaPage> createState() => _FrequenciaPageState();
}

class _FrequenciaPageState extends State<FrequenciaPage> {
  final TextEditingController _pesquisaController =
      TextEditingController();

  String _pesquisa = '';

  final Set<int> _salvandoAlunos = {};
  bool _salvandoLote = false;

  @override
  void initState() {
    super.initState();

    _pesquisaController.addListener(() {
      if (!mounted) return;

      setState(() {
        _pesquisa =
            _pesquisaController.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarChamada();
    });
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  // ============================================================
  // LÓGICA ORIGINAL
  // ============================================================

  Future<void> _carregarChamada() async {
    if (!mounted) return;

    final controller = context.read<FrequenciaController>();

    if (controller.turmaSelecionada == null ||
        controller.turmaSelecionada! <= 0) {
      return;
    }

    await controller.buscarChamada();
  }

  bool _alunoEstaSalvando(int idAluno) {
    return _salvandoAlunos.contains(idAluno);
  }

  Future<void> _alterarStatusAluno(
    FrequenciaController controller,
    dynamic aluno,
    bool novoPresente,
  ) async {
    final int idAluno = aluno.idAluno;

    if (_salvandoLote) return;

    if (_salvandoAlunos.contains(idAluno)) return;

    if (controller.turmaSelecionada == null ||
        controller.turmaSelecionada! <= 0) {
      _mostrarMensagem(
        'Nenhuma turma foi selecionada.',
        erro: true,
      );
      return;
    }

    if (_dataEhFutura(controller.dataSelecionada)) {
      _mostrarMensagem(
        'Não é permitido registrar chamada em uma data futura.',
        erro: true,
      );
      return;
    }

    final String novoStatus =
        novoPresente ? 'Presente' : 'Ausente';

    if (aluno.status == novoStatus) {
      return;
    }

    final String statusAnterior =
        aluno.status?.toString() ?? 'Ausente';

    aluno.status = novoStatus;

    setState(() {
      _salvandoAlunos.add(idAluno);
    });

    try {
      bool sucesso;

      if (novoStatus == 'Presente') {
        sucesso = await controller.registrarPresencaFacial(
          idAluno,
        );
      } else {
        sucesso = await controller.registrarAusencia(
          idAluno,
        );
      }

      if (!mounted) return;

      if (!sucesso) {
        aluno.status = statusAnterior;

        _mostrarMensagem(
          'Não foi possível salvar a frequência.',
          erro: true,
        );

        setState(() {});
        return;
      }

      _mostrarMensagem(
        '${aluno.nome} marcado como $novoStatus.',
        sucesso: true,
      );
    } catch (e, stackTrace) {
      debugPrint(
        'ERRO AO ALTERAR STATUS DO ALUNO: $e',
      );

      debugPrint(
        'STACK: $stackTrace',
      );

      if (!mounted) return;

      aluno.status = statusAnterior;

      _mostrarMensagem(
        'Erro ao salvar a frequência.',
        erro: true,
      );

      setState(() {});
    } finally {
      if (mounted) {
        setState(() {
          _salvandoAlunos.remove(idAluno);
        });
      }
    }
  }

  String _getIniciais(String nome) {
    if (nome.trim().isEmpty) {
      return '?';
    }

    final partes = nome.trim().split(RegExp(r'\s+'));

    if (partes.length == 1) {
      return partes[0]
          .substring(
            0,
            partes[0].length >= 2 ? 2 : 1,
          )
          .toUpperCase();
    }

    return (
      partes.first[0] +
      partes[1][0]
    ).toUpperCase();
  }

  bool _dataEhFutura(DateTime data) {
    final hoje = DateTime.now();

    final hojeSemHora = DateTime(
      hoje.year,
      hoje.month,
      hoje.day,
    );

    final dataSemHora = DateTime(
      data.year,
      data.month,
      data.day,
    );

    return dataSemHora.isAfter(hojeSemHora);
  }

  Map<String, dynamic>? _getTurmaSelecionada(
    FrequenciaController controller,
  ) {
    final idSelecionado = controller.turmaSelecionada;

    if (idSelecionado == null) {
      return null;
    }

    for (final turma in controller.turmas) {
      final idTurma = int.tryParse(
        turma['id_turma'].toString(),
      );

      if (idTurma == idSelecionado) {
        return turma;
      }
    }

    return null;
  }

  String _getNomeTurma(
    FrequenciaController controller,
  ) {
    final turma = _getTurmaSelecionada(controller);

    if (turma == null) {
      return 'Turma não selecionada';
    }

    final nome =
        turma['nome_turma']?.toString().trim() ?? '';

    final serie =
        turma['serie']?.toString().trim() ?? '';

    if (nome.isNotEmpty) return nome;

    if (serie.isNotEmpty) return serie;

    return 'Turma ${controller.turmaSelecionada}';
  }

  String _getDetalhesTurma(
    FrequenciaController controller,
  ) {
    final turma = _getTurmaSelecionada(controller);

    if (turma == null) {
      return 'Selecione uma turma para continuar';
    }

    final periodo =
        turma['periodo']?.toString().trim() ?? '';

    final sala =
        turma['sala']?.toString().trim().isNotEmpty == true
            ? turma['sala'].toString().trim()
            : turma['numero_sala']
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true
                ? turma['numero_sala'].toString().trim()
                : turma['sala_turma']
                            ?.toString()
                            .trim()
                            .isNotEmpty ==
                        true
                    ? turma['sala_turma'].toString().trim()
                    : '';

    final informacoes = <String>[];

    if (periodo.isNotEmpty) {
      informacoes.add(periodo);
    }

    if (sala.isNotEmpty) {
      informacoes.add(
        sala.toLowerCase().startsWith('sala')
            ? sala
            : 'Sala $sala',
      );
    }

    if (informacoes.isEmpty) {
      return 'Turma selecionada';
    }

    return informacoes.join(' • ');
  }

  Future<void> _selecionarData(
    FrequenciaController controller,
  ) async {
    final agora = DateTime.now();

    final hoje = DateTime(
      agora.year,
      agora.month,
      agora.day,
    );

    DateTime dataInicial = DateTime(
      controller.dataSelecionada.year,
      controller.dataSelecionada.month,
      controller.dataSelecionada.day,
    );

    if (dataInicial.isAfter(hoje)) {
      dataInicial = hoje;
    }

    const anoInicial = 2025;

    final primeiraData =
        DateTime(anoInicial, 1, 1);

    if (dataInicial.isBefore(primeiraData)) {
      dataInicial = primeiraData;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: dataInicial,
      firstDate: primeiraData,
      lastDate: hoje,
      helpText: 'Selecione a data da aula',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: SifeTheme.primaryRed,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF172033),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    final dataEscolhida = DateTime(
      picked.year,
      picked.month,
      picked.day,
    );

    await controller.mudarData(dataEscolhida);
  }

  Future<void> _atualizar(
    FrequenciaController controller,
  ) async {
    if (_salvandoAlunos.isNotEmpty ||
        _salvandoLote) {
      return;
    }

    await controller.buscarChamada();

    if (!mounted) return;

    _mostrarMensagem(
      'Frequência atualizada.',
      sucesso: true,
    );
  }

  Future<void> _salvarChamadaLote(
    FrequenciaController controller,
  ) async {
    if (_salvandoLote) return;

    if (controller.turmaSelecionada == null ||
        controller.turmaSelecionada! <= 0) {
      _mostrarMensagem(
        'Nenhuma turma foi selecionada.',
        erro: true,
      );
      return;
    }

    if (controller.alunos.isEmpty) {
      _mostrarMensagem(
        'Não existem alunos para registrar a chamada.',
        erro: true,
      );
      return;
    }

    if (_dataEhFutura(controller.dataSelecionada)) {
      _mostrarMensagem(
        'Não é permitido registrar chamada em uma data futura.',
        erro: true,
      );
      return;
    }

    final alunosParaSalvar =
        List<dynamic>.from(controller.alunos);

    setState(() {
      _salvandoLote = true;

      for (final aluno in alunosParaSalvar) {
        _salvandoAlunos.add(aluno.idAluno);
      }
    });

    final resultados = await Future.wait(
      alunosParaSalvar.map(
        (aluno) async {
          try {
            if (aluno.status == 'Presente') {
              return await controller.registrarPresencaFacial(
                aluno.idAluno,
              );
            }

            return await controller.registrarAusencia(
              aluno.idAluno,
            );
          } catch (e) {
            debugPrint(
              'Erro ao salvar aluno ${aluno.idAluno}: $e',
            );

            return false;
          }
        },
      ),
    );

    if (!mounted) return;

    int sucessos = 0;
    int erros = 0;

    for (final resultado in resultados) {
      if (resultado) {
        sucessos++;
      } else {
        erros++;
      }
    }

    setState(() {
      _salvandoLote = false;

      for (final aluno in alunosParaSalvar) {
        _salvandoAlunos.remove(aluno.idAluno);
      }
    });

    if (erros == 0) {
      _mostrarMensagem(
        '$sucessos aluno(s) salvo(s) com sucesso!',
        sucesso: true,
      );
    } else {
      _mostrarMensagem(
        '$sucessos salvo(s) e $erros com erro.',
        aviso: true,
      );
    }
  }

  Future<void> _abrirTotem(
    FrequenciaController controller,
  ) async {
    if (controller.turmaSelecionada == null ||
        controller.turmaSelecionada! <= 0) {
      _mostrarMensagem(
        'Nenhuma turma foi selecionada.',
        erro: true,
      );
      return;
    }

    if (_dataEhFutura(controller.dataSelecionada)) {
      _mostrarMensagem(
        'Não é permitido registrar chamada em uma data futura.',
        erro: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const TotemFacialPage(),
        settings: RouteSettings(
          arguments: {
            'id_turma':
                controller.turmaSelecionada,
          },
        ),
      ),
    );
  }

  Future<void> _cadastrarRosto(
    FrequenciaController controller,
  ) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const CadastroRostoPage(),
      ),
    );

    if (!mounted) return;

    if (resultado == true) {
      _mostrarMensagem(
        'Rosto cadastrado com sucesso.',
        sucesso: true,
      );
    }
  }

  Future<void> _marcarTodosPresentes(
    FrequenciaController controller,
  ) async {
    if (_salvandoLote) return;

    if (controller.alunos.isEmpty) return;

    if (_dataEhFutura(controller.dataSelecionada)) {
      _mostrarMensagem(
        'Não é permitido registrar chamada em uma data futura.',
        erro: true,
      );
      return;
    }

    int alterados = 0;

    for (final aluno in controller.alunos) {
      if (aluno.status != 'Presente') {
        aluno.status = 'Presente';
        alterados++;
      }
    }

    if (mounted) {
      setState(() {});
    }

    _mostrarMensagem(
      alterados == 0
          ? 'Todos os alunos já estão presentes.'
          : '$alterados aluno(s) marcado(s) como presente.',
      sucesso: alterados > 0,
      aviso: alterados == 0,
    );
  }

  Future<void> _marcarTodosAusentes(
    FrequenciaController controller,
  ) async {
    if (_salvandoLote) return;

    if (controller.alunos.isEmpty) return;

    if (_dataEhFutura(controller.dataSelecionada)) {
      _mostrarMensagem(
        'Não é permitido registrar chamada em uma data futura.',
        erro: true,
      );
      return;
    }

    int alterados = 0;

    for (final aluno in controller.alunos) {
      if (aluno.status != 'Ausente') {
        aluno.status = 'Ausente';
        alterados++;
      }
    }

    if (mounted) {
      setState(() {});
    }

    _mostrarMensagem(
      alterados == 0
          ? 'Todos os alunos já estão ausentes.'
          : '$alterados aluno(s) marcado(s) como ausente.',
      sucesso: alterados > 0,
      aviso: alterados == 0,
    );
  }

  void _voltarParaTurmas() {
    if (_salvandoAlunos.isNotEmpty ||
        _salvandoLote) {
      return;
    }

    Navigator.of(context).pop();
  }

  void _mostrarMensagem(
    String mensagem, {
    bool sucesso = false,
    bool erro = false,
    bool aviso = false,
  }) {
    if (!mounted) return;

    Color cor = const Color(0xFF334155);

    if (sucesso) {
      cor = const Color(0xFF16A34A);
    } else if (erro) {
      cor = const Color(0xFFD92D20);
    } else if (aviso) {
      cor = const Color(0xFFF59E0B);
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration:
              const Duration(seconds: 2),
          backgroundColor: cor,
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                sucesso
                    ? Icons.check_circle_outline
                    : erro
                        ? Icons.error_outline
                        : Icons.info_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mensagem,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  List<dynamic> _alunosFiltrados(
    FrequenciaController controller,
  ) {
    if (_pesquisa.isEmpty) {
      return controller.alunos;
    }

    return controller.alunos.where(
      (aluno) {
        final nome =
            aluno.nome.toLowerCase();

        final matricula =
            aluno.idAluno.toString();

        return nome.contains(_pesquisa) ||
            matricula.contains(_pesquisa);
      },
    ).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final controller =
        context.watch<FrequenciaController>();

    final largura =
        MediaQuery.of(context).size.width;

    final celular = largura < 600;
    final tablet =
        largura >= 600 && largura < 1000;

    final dataFutura =
        _dataEhFutura(controller.dataSelecionada);

    final podeRegistrar =
        controller.turmaSelecionada != null &&
        controller.turmaSelecionada! > 0 &&
        controller.alunos.isNotEmpty &&
        !dataFutura &&
        !controller.carregando &&
        !_salvandoLote;

    final alunosFiltrados =
        _alunosFiltrados(controller);

    final total =
        controller.alunos.length;

    final presentes =
        controller.alunos
            .where(
              (aluno) =>
                  aluno.status == 'Presente',
            )
            .length;

    final ausentes =
        total - presentes;

    final aproveitamento =
        total > 0
            ? (presentes / total) * 100
            : 0.0;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF4F6F8),
      floatingActionButton:
          _buildTotemButton(controller),
      body: SafeArea(
        child: controller.carregando &&
                controller.alunos.isEmpty
            ? const Center(
                child:
                    CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(
                    SifeTheme.primaryRed,
                  ),
                ),
              )
            : RefreshIndicator(
                color:
                    SifeTheme.primaryRed,
                onRefresh: () =>
                    _atualizar(controller),
                child:
                    SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      EdgeInsets.fromLTRB(
                    celular
                        ? 16
                        : tablet
                            ? 26
                            : 40,
                    celular ? 18 : 30,
                    celular
                        ? 16
                        : tablet
                            ? 26
                            : 40,
                    celular ? 115 : 105,
                  ),
                  child: Center(
                    child:
                        ConstrainedBox(
                      constraints:
                          const BoxConstraints(
                        maxWidth: 1450,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _buildVoltar(),
                          const SizedBox(height: 24),

                          _buildCabecalho(
                            largura: largura,
                            celular: celular,
                            tablet: tablet,
                            controller:
                                controller,
                            podeRegistrar:
                                podeRegistrar,
                          ),

                          const SizedBox(height: 28),

                          _buildTurma(
                            controller,
                            celular,
                          ),

                          const SizedBox(height: 18),

                          if (dataFutura)
                            _buildAvisoDataFutura(),

                          _buildControles(
                            controller,
                            dataFutura,
                            podeRegistrar,
                            celular,
                          ),

                          const SizedBox(height: 20),

                          _buildEstatisticas(
                            total: total,
                            presentes: presentes,
                            ausentes: ausentes,
                            aproveitamento:
                                aproveitamento,
                            largura: largura,
                          ),

                          const SizedBox(height: 22),

                          _buildListaAlunos(
                            controller,
                            alunosFiltrados,
                            total,
                            podeRegistrar,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ============================================================
  // CABEÇALHO
  // ============================================================

  Widget _buildVoltar() {
    final bloqueado =
        _salvandoAlunos.isNotEmpty ||
        _salvandoLote;

    return InkWell(
      onTap:
          bloqueado
              ? null
              : _voltarParaTurmas,
      borderRadius:
          BorderRadius.circular(10),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 6,
          horizontal: 2,
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_rounded,
              size: 19,
              color:
                  bloqueado
                      ? Colors.grey
                      : SifeTheme.primaryRed,
            ),
            const SizedBox(width: 7),
            Text(
              'Voltar para Turmas',
              style: TextStyle(
                color:
                    bloqueado
                        ? Colors.grey
                        : SifeTheme.primaryRed,
                fontSize: 14,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCabecalho({
    required double largura,
    required bool celular,
    required bool tablet,
    required FrequenciaController controller,
    required bool podeRegistrar,
  }) {
    final botoes =
        _buildBotoesCabecalho(
      controller,
      podeRegistrar,
    );

    if (celular || tablet) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildTitulo(),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: botoes,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _buildTitulo(),
        ),
        const SizedBox(width: 30),
        Flexible(
          child: Align(
            alignment:
                Alignment.centerRight,
            child: botoes,
          ),
        ),
      ],
    );
  }

  Widget _buildTitulo() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration:
              BoxDecoration(
            color:
                const Color(0xFFFEE2E2),
            borderRadius:
                BorderRadius.circular(7),
          ),
          child: const Text(
            'REGISTRO DE AULA',
            style: TextStyle(
              fontSize: 10,
              fontWeight:
                  FontWeight.w900,
              color:
                  SifeTheme.primaryRed,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Frequência',
          style: TextStyle(
            fontSize: 32,
            height: 1.05,
            fontWeight:
                FontWeight.w900,
            color:
                Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Gerencie a presença dos alunos desta turma.',
          style: TextStyle(
            fontSize: 14,
            color:
                Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTÕES
  // ============================================================

  Widget _buildBotoesCabecalho(
    FrequenciaController controller,
    bool podeRegistrar,
  ) {
    return Wrap(
      alignment:
          WrapAlignment.end,
      spacing: 9,
      runSpacing: 9,
      children: [
        OutlinedButton.icon(
          style:
              OutlinedButton.styleFrom(
            backgroundColor:
                Colors.white,
            foregroundColor:
                const Color(0xFF334155),
            padding:
                const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 14,
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(11),
            ),
            side: BorderSide(
              color:
                  const Color(0xFFE2E8F0),
            ),
          ),
          icon: const FaIcon(
            FontAwesomeIcons.userPlus,
            size: 13,
            color:
                SifeTheme.primaryRed,
          ),
          label: const Text(
            'Cadastrar Rosto',
            style: TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          onPressed:
              _salvandoLote
                  ? null
                  : () =>
                      _cadastrarRosto(
                        controller,
                      ),
        ),
        ElevatedButton.icon(
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                podeRegistrar
                    ? SifeTheme.primaryRed
                    : Colors.grey.shade400,
            foregroundColor:
                Colors.white,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 19,
              vertical: 14,
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(11),
            ),
          ),
          icon:
              _salvandoLote
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(
                        color:
                            Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const FaIcon(
                      FontAwesomeIcons
                          .floppyDisk,
                      size: 13,
                    ),
          label: Text(
            _salvandoLote
                ? 'SALVANDO...'
                : 'SALVAR CHAMADA',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w800,
              fontSize: 12,
            ),
          ),
          onPressed:
              podeRegistrar
                  ? () =>
                      _salvarChamadaLote(
                        controller,
                      )
                  : null,
        ),
        Material(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(11),
          child: InkWell(
            onTap:
                _salvandoLote ||
                        _salvandoAlunos
                            .isNotEmpty
                    ? null
                    : () =>
                        _atualizar(
                          controller,
                        ),
            borderRadius:
                BorderRadius.circular(11),
            child: Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(11),
                border: Border.all(
                  color:
                      const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 20,
                color:
                    _salvandoLote ||
                            _salvandoAlunos
                                .isNotEmpty
                        ? Colors.grey
                        : SifeTheme.primaryRed,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TURMA
  // ============================================================

  Widget _buildTurma(
    FrequenciaController controller,
    bool celular,
  ) {
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.all(
        celular ? 16 : 20,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.025),
            blurRadius: 18,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width:
                celular ? 46 : 52,
            height:
                celular ? 46 : 52,
            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFFFFE4E6),
                  Color(0xFFFEE2E2),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.school_rounded,
              color:
                  SifeTheme.primaryRed,
              size:
                  celular ? 22 : 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'TURMA SELECIONADA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: .8,
                    color:
                        Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _getNomeTurma(
                    controller,
                  ),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize:
                        celular ? 17 : 19,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        const Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _getDetalhesTurma(
                    controller,
                  ),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AVISO
  // ============================================================

  Widget _buildAvisoDataFutura() {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 18,
      ),
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFFFBEB),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xFFFCD34D),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color:
                Color(0xFFD97706),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'A data selecionada é futura. Não é possível registrar ou alterar a chamada.',
              style: TextStyle(
                color:
                    Color(0xFF92400E),
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTROLES
  // ============================================================

  Widget _buildControles(
    FrequenciaController controller,
    bool dataFutura,
    bool podeRegistrar,
    bool celular,
  ) {
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.all(
        celular ? 14 : 18,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.02),
            blurRadius: 16,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder:
                (context, constraints) {
              final pequeno =
                  constraints.maxWidth < 700;

              if (pequeno) {
                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    _buildDataButton(
                      controller,
                      dataFutura,
                    ),
                    const SizedBox(height: 9),
                    _buildTodosPresentes(
                      controller,
                      podeRegistrar,
                      fullWidth: true,
                    ),
                    const SizedBox(height: 9),
                    _buildTodosAusentes(
                      controller,
                      podeRegistrar,
                      fullWidth: true,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child:
                        _buildDataButton(
                      controller,
                      dataFutura,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildTodosPresentes(
                    controller,
                    podeRegistrar,
                  ),
                  const SizedBox(width: 8),
                  _buildTodosAusentes(
                    controller,
                    podeRegistrar,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller:
                _pesquisaController,
            enabled:
                !_salvandoLote,
            style: const TextStyle(
              fontSize: 14,
              fontWeight:
                  FontWeight.w500,
            ),
            decoration:
                InputDecoration(
              hintText:
                  'Pesquisar aluno por nome ou matrícula...',
              hintStyle: TextStyle(
                color:
                    Colors.grey.shade400,
                fontSize: 13,
              ),
              prefixIcon:
                  Icon(
                Icons.search_rounded,
                color:
                    Colors.grey.shade500,
                size: 21,
              ),
              suffixIcon:
                  _pesquisa.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _pesquisaController
                                .clear();
                          },
                          icon:
                              const Icon(
                            Icons.close_rounded,
                            size: 19,
                          ),
                        )
                      : null,
              filled: true,
              fillColor:
                  const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(
                vertical: 15,
                horizontal: 15,
              ),
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide:
                    BorderSide(
                  color:
                      const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide:
                    const BorderSide(
                  color:
                      SifeTheme.primaryRed,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATA
  // ============================================================

  Widget _buildDataButton(
    FrequenciaController controller,
    bool dataFutura,
  ) {
    return InkWell(
      onTap:
          _salvandoLote
              ? null
              : () =>
                  _selecionarData(
                    controller,
                  ),
      borderRadius:
          BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 10,
        ),
        decoration:
            BoxDecoration(
          color:
              const Color(0xFFF8FAFC),
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: dataFutura
                ? const Color(0xFFF59E0B)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color: dataFutura
                    ? const Color(0xFFFFEDD5)
                    : const Color(0xFFFEE2E2),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: dataFutura
                    ? const Color(0xFFD97706)
                    : SifeTheme.primaryRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'DATA DA AULA',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: .6,
                      color:
                          Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.dataFormatada,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(0xFF172033),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color:
                  Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PRESENTES / AUSENTES
  // ============================================================

  Widget _buildTodosPresentes(
    FrequenciaController controller,
    bool podeRegistrar, {
    bool fullWidth = false,
  }) {
    return SizedBox(
      width:
          fullWidth ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed:
            podeRegistrar &&
                    !_salvandoLote
                ? () =>
                    _marcarTodosPresentes(
                      controller,
                    )
                : null,
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              const Color(0xFF15803D),
          backgroundColor:
              const Color(0xFFF0FDF4),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          side: const BorderSide(
            color:
                Color(0xFFBBF7D0),
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(11),
          ),
        ),
        icon: const Icon(
          Icons.check_circle_outline,
          size: 17,
          color:
              Color(0xFF16A34A),
        ),
        label: const Text(
          'Todos presentes',
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildTodosAusentes(
    FrequenciaController controller,
    bool podeRegistrar, {
    bool fullWidth = false,
  }) {
    return SizedBox(
      width:
          fullWidth ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed:
            podeRegistrar &&
                    !_salvandoLote
                ? () =>
                    _marcarTodosAusentes(
                      controller,
                    )
                : null,
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              const Color(0xFFB91C1C),
          backgroundColor:
              const Color(0xFFFEF2F2),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          side: const BorderSide(
            color:
                Color(0xFFFECACA),
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(11),
          ),
        ),
        icon: const Icon(
          Icons.cancel_outlined,
          size: 17,
          color:
              Color(0xFFDC2626),
        ),
        label: const Text(
          'Todos ausentes',
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ESTATÍSTICAS
  // ============================================================

  Widget _buildEstatisticas({
    required int total,
    required int presentes,
    required int ausentes,
    required double aproveitamento,
    required double largura,
  }) {
    final celular = largura < 600;

    final cards = [
      _buildStatCard(
        title: 'TOTAL',
        value: total.toString(),
        icon: Icons.groups_rounded,
        valueColor:
            const Color(0xFF334155),
      ),
      _buildStatCard(
        title: 'PRESENTES',
        value: presentes.toString(),
        icon: Icons.check_circle_rounded,
        valueColor:
            const Color(0xFF16A34A),
      ),
      _buildStatCard(
        title: 'AUSENTES',
        value: ausentes.toString(),
        icon: Icons.cancel_rounded,
        valueColor:
            const Color(0xFFDC2626),
      ),
      _buildStatCard(
        title: 'APROVEITAMENTO',
        value:
            '${aproveitamento.toStringAsFixed(0)}%',
        icon: Icons.analytics_rounded,
        valueColor:
            const Color(0xFF2563EB),
        progress:
            aproveitamento / 100,
      ),
    ];

    if (celular) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics:
            const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.48,
        children: cards,
      );
    }

    return Row(
      children:
          cards
              .map(
                (card) => Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 5,
                    ),
                    child: card,
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color valueColor,
    double? progress,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.025),
            blurRadius: 15,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color:
                  valueColor.withOpacity(.08),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: valueColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: .6,
                    color:
                        Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight:
                        FontWeight.w900,
                    color: valueColor,
                  ),
                ),
                if (progress != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 5,
                    ),
                    child:
                        ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                      child:
                          LinearProgressIndicator(
                        value:
                            progress.clamp(
                          0.0,
                          1.0,
                        ),
                        minHeight: 5,
                        backgroundColor:
                            const Color(
                          0xFFEFF2F5,
                        ),
                        valueColor:
                            AlwaysStoppedAnimation<
                                Color>(
                          valueColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LISTA
  // ============================================================

  Widget _buildListaAlunos(
    FrequenciaController controller,
    List<dynamic> alunosFiltrados,
    int total,
    bool podeRegistrar,
  ) {
    return Container(
      width: double.infinity,
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.025),
            blurRadius: 18,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              16,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(0xFFFEE2E2),
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color:
                        SifeTheme.primaryRed,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alunos',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              Color(0xFF172033),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Controle individual de presença',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(0xFFF8FAFC),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    _pesquisa.isNotEmpty
                        ? '${alunosFiltrados.length} encontrados'
                        : '$total alunos',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            color:
                Color(0xFFEFF1F4),
          ),
          if (alunosFiltrados.isEmpty)
            _buildListaVazia()
          else
            ListView.separated(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              itemCount:
                  alunosFiltrados.length,
              separatorBuilder:
                  (context, index) =>
                      const Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color:
                    Color(0xFFF1F3F5),
              ),
              itemBuilder:
                  (context, index) {
                final aluno =
                    alunosFiltrados[index];

                final isPresente =
                    aluno.status ==
                        'Presente';

                return _buildAlunoRow(
                  controller,
                  aluno,
                  isPresente,
                  podeRegistrar,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildListaVazia() {
    return Padding(
      padding:
          const EdgeInsets.all(50),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFF8FAFC),
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Icon(
              _pesquisa.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.groups_outlined,
              size: 32,
              color:
                  Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _pesquisa.isNotEmpty
                ? 'Nenhum aluno encontrado'
                : 'Nenhum aluno cadastrado',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w800,
              color:
                  Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _pesquisa.isNotEmpty
                ? 'Tente pesquisar por outro nome ou matrícula.'
                : 'Não há alunos disponíveis nesta turma.',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 12,
              color:
                  Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ALUNO
  // ============================================================

  Widget _buildAlunoRow(
    FrequenciaController controller,
    dynamic aluno,
    bool isPresente,
    bool podeRegistrar,
  ) {
    final idAluno =
        aluno.idAluno;

    final salvando =
        _salvandoAlunos.contains(
      idAluno,
    );

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 13,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildAvatarAluno(
                  aluno,
                  isPresente,
                  44,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child:
                      _buildInfoAluno(
                    aluno,
                  ),
                ),
              ],
            ),
          ),
          if (salvando)
            const Padding(
              padding:
                  EdgeInsets.only(
                right: 12,
              ),
              child:
                  SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      SifeTheme.primaryRed,
                ),
              ),
            ),
          SizedBox(
            width: 190,
            child: Row(
              children: [
                Expanded(
                  child:
                      _buildStatusButton(
                    label: 'Presente',
                    ativo:
                        isPresente,
                    verde: true,
                    habilitado:
                        podeRegistrar &&
                            !salvando,
                    onTap: () =>
                        _alterarStatusAluno(
                      controller,
                      aluno,
                      true,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child:
                      _buildStatusButton(
                    label: 'Ausente',
                    ativo:
                        !isPresente,
                    verde: false,
                    habilitado:
                        podeRegistrar &&
                            !salvando,
                    onTap: () =>
                        _alterarStatusAluno(
                      controller,
                      aluno,
                      false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildAvatarAluno(
    dynamic aluno,
    bool isPresente,
    double tamanho,
  ) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration:
          BoxDecoration(
        gradient:
            LinearGradient(
          colors: isPresente
              ? const [
                  Color(0xFFDCFCE7),
                  Color(0xFFBBF7D0),
                ]
              : const [
                  Color(0xFFF1F5F9),
                  Color(0xFFE2E8F0),
                ],
        ),
        borderRadius:
            BorderRadius.circular(13),
      ),
      child: Center(
        child: Text(
          _getIniciais(
            aluno.nome,
          ),
          style:
              TextStyle(
            color: isPresente
                ? const Color(0xFF15803D)
                : const Color(0xFF475569),
            fontWeight:
                FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INFORMAÇÕES
  // ============================================================

  Widget _buildInfoAluno(
    dynamic aluno,
  ) {
    final possuiRosto =
        aluno.temRosto;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          aluno.nome,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontWeight:
FontWeight.w700,
            fontSize: 14,
            color:
                Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Matrícula: ${aluno.idAluno}',
          style: const TextStyle(
            color:
                Color(0xFF94A3B8),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(
                color: possuiRosto
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFF59E0B),
                shape:
                    BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                possuiRosto
                    ? 'Rosto cadastrado'
                    : (FaceTestConfig.ativo &&
                            aluno.temRostoTeste
                        ? 'Foto de teste cadastrada'
                        : 'Rosto pendente'),
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w600,
                  color: possuiRosto
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB45309),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // BOTÃO STATUS
  // ============================================================

  Widget _buildStatusButton({
    required String label,
    required bool ativo,
    required bool verde,
    required bool habilitado,
    required VoidCallback onTap,
  }) {
    final cor = verde
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    final fundo = verde
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFEF2F2);

    return InkWell(
      onTap:
          habilitado ? onTap : null,
      borderRadius:
          BorderRadius.circular(9),
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 160,
        ),
        padding:
            const EdgeInsets.symmetric(
          vertical: 9,
          horizontal: 7,
        ),
        decoration:
            BoxDecoration(
          color: !habilitado
              ? const Color(0xFFF1F5F9)
              : ativo
                  ? fundo
                  : Colors.white,
          borderRadius:
              BorderRadius.circular(9),
          border:
              Border.all(
            color: !habilitado
                ? const Color(0xFFE2E8F0)
                : ativo
                    ? cor.withOpacity(.7)
                    : const Color(0xFFE2E8F0),
            width:
                ativo ? 1.3 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              verde
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              size: 14,
              color: !habilitado
                  ? Colors.grey.shade400
                  : ativo
                      ? cor
                      : Colors.grey.shade400,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      FontWeight.w800,
                  color: !habilitado
                      ? Colors.grey.shade400
                      : ativo
                          ? cor
                          : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOTEM
  // ============================================================

  Widget _buildTotemButton(
    FrequenciaController controller,
  ) {
    final dataFutura =
        _dataEhFutura(
      controller.dataSelecionada,
    );

    final podeRegistrar =
        controller.turmaSelecionada != null &&
        controller.turmaSelecionada! > 0 &&
        controller.alunos.isNotEmpty &&
        !dataFutura &&
        !_salvandoLote;

    return FloatingActionButton.extended(
      backgroundColor:
          podeRegistrar
              ? SifeTheme.primaryRed
              : Colors.grey.shade400,
      elevation: 5,
      icon: const FaIcon(
        FontAwesomeIcons.expand,
        color: Colors.white,
        size: 14,
      ),
      label: Text(
        _salvandoLote
            ? 'Salvando...'
            : 'Ativar Modo Totem',
        style:
            const TextStyle(
          color: Colors.white,
          fontWeight:
              FontWeight.w800,
          fontSize: 12,
        ),
      ),
      onPressed:
          podeRegistrar
              ? () => _abrirTotem(
                    controller,
                  )
              : null,
    );
  }
}
