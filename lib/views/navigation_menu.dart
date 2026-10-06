
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import 'frequencia_page.dart';
import 'totem_facial_page.dart';
import 'cadastro_rosto_page.dart';
import 'login_page.dart';

class NavigationMenu extends StatefulWidget {
  const NavigationMenu({Key? key}) : super(key: key);

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  int _indiceSelecionado = 0;

  final List<Widget> _telas = const [
    FrequenciaPage(),
    TotemFacialPage(),
    CadastroRostoPage(),
  ];

  final List<String> _titulos = const [
    'Frequência',
    'Totem Facial',
    'Cadastrar Rosto',
  ];

  final List<String> _subtitulos = const [
    'Gerencie a presença dos alunos',
    'Controle o reconhecimento facial',
    'Cadastre o rosto dos alunos',
  ];

  // ============================================================
  // DADOS DO PROFESSOR
  // ============================================================

  Future<Map<String, String>> _buscarDadosProfessor() async {
    final prefs = await SharedPreferences.getInstance();

    final nome = prefs.getString('usuario_nome') ??
        prefs.getString('professor_nome') ??
        prefs.getString('name') ??
        prefs.getString('nome') ??
        '';

    final email = prefs.getString('usuario_email') ??
        prefs.getString('professor_email') ??
        prefs.getString('email') ??
        '';

    return {
      'nome': nome.isNotEmpty ? nome : 'Professor(a)',
      'email': email.isNotEmpty ? email : 'Sem e-mail cadastrado',
    };
  }

  String _gerarInicial(String nome) {
    final texto = nome.trim();

    if (texto.isEmpty) {
      return 'P';
    }

    final partes = texto.split(RegExp(r'\s+'));

    if (partes.length >= 2) {
      return '${partes.first[0]}${partes[1][0]}'.toUpperCase();
    }

    return partes.first[0].toUpperCase();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,

        leading: Builder(
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.only(left: 14),
              child: IconButton(
                tooltip: 'Abrir menu',
                splashRadius: 24,
                icon: const FaIcon(
                  FontAwesomeIcons.barsStaggered,
                  color: SifeTheme.textDark,
                  size: 19,
                ),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            );
          },
        ),

        titleSpacing: 4,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _titulos[_indiceSelecionado],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SifeTheme.textDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _subtitulos[_indiceSelecionado],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.blueGrey.shade400,
              ),
            ),
          ],
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: FutureBuilder<Map<String, String>>(
              future: _buscarDadosProfessor(),
              builder: (context, snapshot) {
                final nome =
                    snapshot.data?['nome'] ?? 'Professor(a)';

                return Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: SifeTheme.primaryRedSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _gerarInicial(nome),
                        style: const TextStyle(
                          color: SifeTheme.primaryRed,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // ========================================================
      // DRAWER
      // ========================================================

      drawer: Drawer(
        width: 300,
        elevation: 10,
        backgroundColor: Colors.white,

        child: SafeArea(
          child: Column(
            children: [
              // ==================================================
              // LOGO / CABEÇALHO
              // ==================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  22,
                  22,
                  20,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: SifeTheme.primaryRed,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:
                                SifeTheme.primaryRed.withOpacity(0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: FaIcon(
                          FontAwesomeIcons.userGraduate,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(width: 13),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SIFE',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: SifeTheme.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Sistema Escolar Inteligente',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blueGrey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ==================================================
              // LINHA
              // ==================================================

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
              ),

              // ==================================================
              // MENU
              // ==================================================

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    20,
                    14,
                    20,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        bottom: 10,
                      ),
                      child: Text(
                        'MENU PRINCIPAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                    ),

                    _buildMenuItem(
                      index: 0,
                      icon: FontAwesomeIcons.calendarCheck,
                      label: 'Frequência',
                      description: 'Controle de presença',
                    ),

                    _buildMenuItem(
                      index: 1,
                      icon: FontAwesomeIcons.expand,
                      label: 'Totem Facial',
                      description: 'Chamada automática',
                    ),

                    _buildMenuItem(
                      index: 2,
                      icon: FontAwesomeIcons.idCard,
                      label: 'Cadastrar Rosto',
                      description: 'Biometria dos alunos',
                    ),

                    const SizedBox(height: 22),

                    Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        bottom: 10,
                      ),
                      child: Text(
                        'SISTEMA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                    ),

                    _buildInfoItem(
                      FontAwesomeIcons.shieldHalved,
                      'Reconhecimento facial',
                    ),

                    _buildInfoItem(
                      FontAwesomeIcons.server,
                      'Sistema conectado',
                    ),
                  ],
                ),
              ),

              // ==================================================
              // ÁREA DO USUÁRIO
              // ==================================================

              Container(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFB),
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.shade200,
                    ),
                  ),
                ),
                child: FutureBuilder<Map<String, String>>(
                  future: _buscarDadosProfessor(),
                  builder: (context, snapshot) {
                    final nome =
                        snapshot.data?['nome'] ?? 'Professor(a)';

                    final email =
                        snapshot.data?['email'] ?? '';

                    final sigla = _gerarInicial(nome);

                    return Column(
                      children: [
                        // PERFIL
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: SifeTheme.primaryRed,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    sigla,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 11),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nome,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            SifeTheme.textDark,
                                      ),
                                    ),

                                    const SizedBox(height: 3),

                                    Text(
                                      email,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color:
                                            Colors.blueGrey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // SAIR
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  SifeTheme.primaryRed,
                              side: BorderSide(
                                color: SifeTheme.primaryRed
                                    .withOpacity(0.35),
                              ),
                              backgroundColor:
                                  SifeTheme.primaryRedSoft
                                      .withOpacity(0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                            icon: const FaIcon(
                              FontAwesomeIcons.rightFromBracket,
                              size: 13,
                            ),
                            label: const Text(
                              'Sair da conta',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: _sairDaConta,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // ========================================================
      // CONTEÚDO
      // ========================================================

      body: IndexedStack(
        index: _indiceSelecionado,
        children: _telas,
      ),
    );
  }

  // ============================================================
  // ITEM PRINCIPAL DO MENU
  // ============================================================

  Widget _buildMenuItem({
    required int index,
    required IconData icon,
    required String label,
    required String description,
  }) {
    final bool selecionado = _indiceSelecionado == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _indiceSelecionado = index;
            });

            Navigator.pop(context);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: selecionado
                  ? SifeTheme.primaryRedSoft
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: selecionado
                  ? Border.all(
                      color: SifeTheme.primaryRed
                          .withOpacity(0.08),
                    )
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selecionado
                        ? SifeTheme.primaryRed
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: FaIcon(
                      icon,
                      size: 16,
                      color: selecionado
                          ? Colors.white
                          : Colors.blueGrey.shade500,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selecionado
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: selecionado
                              ? SifeTheme.primaryRed
                              : SifeTheme.textDark,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 10,
                          color: selecionado
                              ? SifeTheme.primaryRed
                                  .withOpacity(0.65)
                              : Colors.blueGrey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),

                if (selecionado)
                  const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 10,
                    color: SifeTheme.primaryRed,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ITEM INFORMATIVO
  // ============================================================

  Widget _buildInfoItem(
    IconData icon,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      child: Row(
        children: [
          FaIcon(
            icon,
            size: 13,
            color: Colors.blueGrey.shade400,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.blueGrey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _sairDaConta() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();

    ApiService().setToken(null);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
      (route) => false,
    );
  }
}

