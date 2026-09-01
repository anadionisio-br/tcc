import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/theme.dart';
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

  // Lista atualizada com as páginas do sistema
  final List<Widget> _telas = [
    const FrequenciaPage(),
    const TotemFacialPage(),
    const CadastroRostoPage(),
  ];

  final List<String> _titulos = [
    'Registro de Frequência',
    'Totem Facial',
    'Cadastrar Rosto',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SifeTheme.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const FaIcon(
              FontAwesomeIcons.bars,
              color: SifeTheme.textDark,
              size: 20,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titulos[_indiceSelecionado],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: SifeTheme.textDark,
              ),
            ),
            if (_indiceSelecionado == 0)
              Text(
                '8º Ano B • Matutino • Sala 04',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // CABEÇALHO DO MENU
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
                    const SizedBox(width: 14),
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

              // ITENS DE NAVEGAÇÃO
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    _buildMenuItem(
                      0,
                      FontAwesomeIcons.calendarCheck,
                      'Frequência',
                    ),
                    _buildMenuItem(
                      1,
                      FontAwesomeIcons.expand,
                      'Totem Facial',
                    ),
                    _buildMenuItem(
                      2,
                      FontAwesomeIcons.idCard,
                      'Cadastrar Rosto',
                    ),
                  ],
                ),
              ),

              // RODAPÉ DO USUÁRIO E SAIR
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SifeTheme.primaryRedSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: SifeTheme.primaryRed,
                            radius: 18,
                            child: Text(
                              'PA',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Professora',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: SifeTheme.textDark,
                                  ),
                                ),
                                Text(
                                  'professor@gmail.com',
                                  style: TextStyle(
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
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: SifeTheme.primaryRed),
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
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
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
      ),
      body: _telas[_indiceSelecionado],
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String label) {
    bool isSelected = _indiceSelecionado == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
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