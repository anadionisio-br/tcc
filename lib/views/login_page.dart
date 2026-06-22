import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/theme.dart';
import 'navigation_menu.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SifeTheme.bgLight,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Simbolizada do SIFE
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: SifeTheme.primaryRedSoft,
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(FontAwesomeIcons.graduationCap, size: 60, color: SifeTheme.primaryRed),
              ),
              const SizedBox(height: 16),
              const Text('SIFE', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: SifeTheme.textDark, letterSpacing: 1.5)),
              Text('Sistema Integrado de Frequência Escolar', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 40),

              // Card do Formulário
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SifeTheme.borderColor),
                  boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Acesse sua Conta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SifeTheme.textDark)),
                    const SizedBox(height: 20),
                    
                    // Input Email
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'E-mail ou Matrícula',
                        prefixIcon: const Padding(padding: EdgeInsets.all(12), child: FaIcon(FontAwesomeIcons.envelope, size: 16)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SifeTheme.borderColor)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input Senha
                    TextField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Padding(padding: EdgeInsets.all(12), child: FaIcon(FontAwesomeIcons.lock, size: 16)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SifeTheme.borderColor)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botão Entrar
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SifeTheme.primaryRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // Navega para o Menu que gerencia as abas
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const NavigationMenu()),
                        );
                      },
                      child: const Text('Entrar no Sistema', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}