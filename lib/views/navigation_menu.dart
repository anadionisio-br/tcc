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

  // ============================================================
  // BUSCAR DADOS DO PROFESSOR (LOCAL)
  // ============================================================

  Future<Map<String, String>> _buscarDadosProfessor() async {
    final prefs = await SharedPreferences.getInstance();

    // Tenta buscar por todas as variações de chaves possíveis do backend
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

  // Gera as inicial do nome para colocar no CircleAvatar
  String _gerarInicial(String nome) {
    if (nome.trim().isEmpty) return 'P';
    final partes = nome.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return partes[0][0].toUpperCase();
  }

  // ============================================================
  // PÁGINAS
  // ============================================================

  final List<Widget> _telas = [
    const FrequenciaPage(),
    const TotemFacialPage(),
    const CadastroRostoPage(),
  ];

  // ============================================================
  // TÍTULOS DO MENU
  // ============================================================

  final List<String> _titulos = [
    'Frequência',
    'Totem Facial',
    'Cadastrar Rosto',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SifeTheme.bgLight,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,

        leading: Builder(
          builder: (context) {
            return IconButton(
              tooltip: 'Abrir menu',
              icon: const FaIcon(
                FontAwesomeIcons.bars,
                color: SifeTheme.textDark,
                size: 20,
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),

        title: Text(
          _titulos[_indiceSelecionado],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: SifeTheme.textDark,
          ),
        ),
      ),

      // ========================================================
      // MENU LATERAL
      // ========================================================

      drawer: Drawer(
        backgroundColor: Colors.white,

        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              // ==================================================
              // CABEÇALHO DO MENU
              // ==================================================

              Padding(
                padding: const EdgeInsets.all(24.0),

                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),

                      decoration: BoxDecoration(
                        color: SifeTheme.primaryRed,
                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: const FaIcon(
                        FontAwesomeIcons.chalkboardUser,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(
                      width: 14,
                    ),

                    const Text(
                      'SIFE',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: SifeTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // ITENS DE NAVEGAÇÃO
              // ==================================================

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),

                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 12,
                      ),

                      child: Text(
                        'GESTÃO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    // FREQUÊNCIA
                    _buildMenuItem(
                      0,
                      FontAwesomeIcons.calendarCheck,
                      'Frequência',
                    ),

                    // TOTEM
                    _buildMenuItem(
                      1,
                      FontAwesomeIcons.expand,
                      'Totem Facial',
                    ),

                    // CADASTRAR ROSTO
                    _buildMenuItem(
                      2,
                      FontAwesomeIcons.idCard,
                      'Cadastrar Rosto',
                    ),
                  ],
                ),
              ),

              // ==================================================
              // RODAPÉ DO USUÁRIO DINÂMICO
              // ==================================================

              Padding(
                padding: const EdgeInsets.all(16.0),

                child: FutureBuilder<Map<String, String>>(
                  future: _buscarDadosProfessor(),
                  builder: (context, snapshot) {
                    final nome = snapshot.data?['nome'] ?? 'Carregando...';
                    final email = snapshot.data?['email'] ?? '';
                    final sigla = _gerarInicial(nome);

                    return Column(
                      children: [
                        // PERFIL
                        Container(
                          padding: const EdgeInsets.all(12),

                          decoration: BoxDecoration(
                            color: SifeTheme.primaryRedSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),

                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: SifeTheme.primaryRed,
                                radius: 18,

                                child: Text(
                                  sigla,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      nome,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: SifeTheme.textDark,
                                      ),
                                    ),

                                    Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        // SAIR DA CONTA
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),

                            side: const BorderSide(
                              color: SifeTheme.primaryRed,
                            ),

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),

                          icon: const FaIcon(
                            FontAwesomeIcons.rightFromBracket,
                            size: 14,
                            color: SifeTheme.primaryRed,
                          ),

                          label: const Text(
                            'Sair da Conta',
                            style: TextStyle(
                              color: SifeTheme.primaryRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),

                          onPressed: () async {
                            // Limpa dados salvos se necessário ao deslogar
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            ApiService().setToken(null);

                            if (!mounted) return;

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          },
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
      // PÁGINA ATUAL
      // ========================================================

      body: _telas[_indiceSelecionado],
    );
  }

  // ============================================================
  // ITEM DO MENU
  // ============================================================

  Widget _buildMenuItem(
    int index,
    IconData icon,
    String label,
  ) {
    final bool isSelected = _indiceSelecionado == index;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 2,
      ),

      decoration: BoxDecoration(
        color: isSelected ? SifeTheme.primaryRedSoft : Colors.transparent,

        borderRadius: BorderRadius.circular(12),
      ),

      child: ListTile(
        leading: FaIcon(
          icon,
          size: 18,
          color: isSelected ? SifeTheme.primaryRed : Colors.blueGrey.shade400,
        ),

        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? SifeTheme.primaryRed : SifeTheme.textDark,

            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,

            fontSize: 14,
          ),
        ),

        selected: isSelected,

        onTap: () {
          setState(() {
            _indiceSelecionado = index;
          });

          Navigator.pop(context);
        },
      ),
    );
  }
}