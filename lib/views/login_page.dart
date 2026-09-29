
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import 'turmas_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _senhaController =
      TextEditingController();

  bool _mostrarSenha = false;
  bool _carregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _validarLogin() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    if (email.isEmpty) {
      _mostrarMensagem('Digite seu e-mail.');
      return;
    }

    if (senha.isEmpty) {
      _mostrarMensagem('Digite sua senha.');
      return;
    }

    if (!email.contains('@')) {
      _mostrarMensagem('Digite um e-mail válido.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _carregando = true;
    });

    try {
      debugPrint('========================================');
      debugPrint('INICIANDO LOGIN');
      debugPrint('E-mail: $email');
      debugPrint('========================================');

      final resultado = await ApiService().loginProfessor(
        email,
        senha,
      );

      debugPrint('Resposta da API: $resultado');

      if (!mounted) return;

      if (resultado['success'] == true) {
        debugPrint('LOGIN REALIZADO COM SUCESSO');

        final usuario = resultado['usuario'];

        debugPrint(
          'Professor: ${usuario?['nome'] ?? usuario?['name']}',
        );

        debugPrint(
          'ID: ${usuario?['id_usuario'] ?? usuario?['id']}',
        );

        // ============================================================
        // TOKEN
        // ============================================================

        final token = resultado['token']?.toString();

        if (token == null || token.isEmpty) {
          debugPrint(
            'ATENÇÃO: API não retornou token.',
          );

          _mostrarMensagem(
            'Login realizado, mas o servidor não retornou o token de acesso.',
            isErro: true,
          );

          return;
        }

        // ============================================================
        // SALVAR TOKEN
        // ============================================================

        final prefs =
            await SharedPreferences.getInstance();

        await prefs.setString(
          'auth_token',
          token,
        );

        // Configura o token no ApiService
        ApiService().setToken(token);

        // ============================================================
        // SALVAR DADOS DO USUÁRIO
        // ============================================================

        final nomeSalvar =
            (
              usuario?['nome'] ??
              usuario?['name'] ??
              ''
            ).toString();

        final emailSalvar =
            (
              usuario?['email'] ??
              email
            ).toString();

        final idUsuario =
            (
              usuario?['id_usuario'] ??
              usuario?['id'] ??
              ''
            ).toString();

        await prefs.setString(
          'usuario_nome',
          nomeSalvar,
        );

        await prefs.setString(
          'usuario_email',
          emailSalvar,
        );

        await prefs.setString(
          'usuario_id',
          idUsuario,
        );

        debugPrint(
          'Token salvo com sucesso.',
        );

        debugPrint(
          'Usuário salvo: $nomeSalvar',
        );

        // ============================================================
        // IR PARA TURMAS
        // ============================================================

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const TurmasPage(),
          ),
        );
      } else {
        final mensagem =
            resultado['message']?.toString() ??
                resultado['mensagem']?.toString() ??
                'E-mail ou senha incorretos.';

        _mostrarMensagem(
          mensagem,
          isErro: true,
        );
      }
    } on ApiException catch (e) {
      debugPrint('========================================');
      debugPrint('ERRO DA API');
      debugPrint('Contexto: ${e.contexto}');
      debugPrint('Status: ${e.statusCode}');
      debugPrint('Mensagem: ${e.mensagemAmigavel}');
      debugPrint('Detalhes: ${e.detalhesBackend}');
      debugPrint('========================================');

      if (!mounted) return;

      _mostrarMensagem(
        e.mensagemAmigavel,
        isErro: true,
      );
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('ERRO INESPERADO NO LOGIN');
      debugPrint('$e');
      debugPrint('$stackTrace');
      debugPrint('========================================');

      if (!mounted) return;

      _mostrarMensagem(
        'Não foi possível realizar o login. '
        'Verifique a conexão com o servidor.',
        isErro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  void _mostrarMensagem(
    String mensagem, {
    bool isErro = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor:
              isErro ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SifeTheme.bgLight,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.all(20),
                decoration:
                    const BoxDecoration(
                  color:
                      SifeTheme.primaryRedSoft,
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(
                  FontAwesomeIcons.graduationCap,
                  size: 60,
                  color:
                      SifeTheme.primaryRed,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'SIFE',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      SifeTheme.textDark,
                  letterSpacing: 1.5,
                ),
              ),

              Text(
                'Sistema Integrado de Frequência Escolar',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 40),

              Container(
                width: 400,
                padding:
                    const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        SifeTheme.borderColor,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color:
                          Color(0x0D000000),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Acesse sua Conta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            SifeTheme.textDark,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller:
                          _emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      enabled: !_carregando,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          InputDecoration(
                        labelText: 'E-mail',
                        hintText:
                            'Digite seu e-mail',
                        prefixIcon:
                            const Padding(
                          padding:
                              EdgeInsets.all(12),
                          child: FaIcon(
                            FontAwesomeIcons
                                .envelope,
                            size: 16,
                          ),
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller:
                          _senhaController,
                      obscureText:
                          !_mostrarSenha,
                      enabled: !_carregando,
                      textInputAction:
                          TextInputAction.done,
                      onSubmitted:
                          (_) => _validarLogin(),
                      decoration:
                          InputDecoration(
                        labelText: 'Senha',
                        hintText:
                            'Digite sua senha',
                        prefixIcon:
                            const Padding(
                          padding:
                              EdgeInsets.all(12),
                          child: FaIcon(
                            FontAwesomeIcons.lock,
                            size: 16,
                          ),
                        ),
                        suffixIcon:
                            IconButton(
                          onPressed:
                              _carregando
                                  ? null
                                  : () {
                                      setState(() {
                                        _mostrarSenha =
                                            !_mostrarSenha;
                                      });
                                    },
                          icon: FaIcon(
                            _mostrarSenha
                                ? FontAwesomeIcons
                                    .eyeSlash
                                : FontAwesomeIcons
                                    .eye,
                            size: 16,
                          ),
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              SifeTheme
                                  .primaryRed,
                          disabledBackgroundColor:
                              SifeTheme
                                  .primaryRed
                                  .withValues(
                            alpha: 0.6,
                          ),
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 16,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed:
                            _carregando
                                ? null
                                : _validarLogin,
                        child: _carregando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(
                                  color:
                                      Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Entrar no Sistema',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
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

