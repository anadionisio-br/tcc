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

        final prefs =
            await SharedPreferences.getInstance();

        await prefs.setString(
          'auth_token',
          token,
        );

        ApiService().setToken(token);

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
          content: Row(
            children: [
              Icon(
                isErro
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mensagem,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isErro
              ? const Color(0xFFD92D20)
              : const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final celular = largura < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: celular ? 20 : 32,
                vertical: celular ? 24 : 40,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight -
                      (celular ? 48 : 80),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 440,
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        _buildLogo(celular),

                        const SizedBox(height: 24),

                        _buildLoginCard(celular),

                        const SizedBox(height: 22),

                        _buildRodape(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // LOGO
  // ============================================================

  Widget _buildLogo(bool celular) {
    return Column(
      children: [
        Container(
          width: celular ? 78 : 86,
          height: celular ? 78 : 86,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFF1D5D5),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 25,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: celular ? 58 : 64,
              height: celular ? 58 : 64,
              decoration: BoxDecoration(
                color: SifeTheme.primaryRed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        SifeTheme.primaryRed.withOpacity(.20),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: FaIcon(
                  FontAwesomeIcons.graduationCap,
                  size: celular ? 27 : 30,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          'SIFE',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: SifeTheme.textDark,
            letterSpacing: 2.5,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'Sistema Integrado de Frequência Escolar',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CARD LOGIN
  // ============================================================

  Widget _buildLoginCard(bool celular) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        celular ? 22 : 30,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE9EDF2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bem-vindo de volta',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Entre com seus dados para acessar o sistema.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 26),

          _buildCampoEmail(),

          const SizedBox(height: 16),

          _buildCampoSenha(),

          const SizedBox(height: 24),

          _buildBotaoLogin(),
        ],
      ),
    );
  }

  // ============================================================
  // EMAIL
  // ============================================================

  Widget _buildCampoEmail() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      enabled: !_carregando,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: 'E-mail',
        hintText: 'Digite seu e-mail',
        prefixIcon: const Icon(
          Icons.mail_outline_rounded,
          size: 20,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
        ),
        prefixIconColor:
            const Color(0xFF64748B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: SifeTheme.primaryRed,
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SENHA
  // ============================================================

  Widget _buildCampoSenha() {
    return TextField(
      controller: _senhaController,
      obscureText: !_mostrarSenha,
      enabled: !_carregando,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _validarLogin(),
      decoration: InputDecoration(
        labelText: 'Senha',
        hintText: 'Digite sua senha',
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 20,
        ),
        suffixIcon: IconButton(
          tooltip: _mostrarSenha
              ? 'Ocultar senha'
              : 'Mostrar senha',
          onPressed: _carregando
              ? null
              : () {
                  setState(() {
                    _mostrarSenha =
                        !_mostrarSenha;
                  });
                },
          icon: Icon(
            _mostrarSenha
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
        ),
        prefixIconColor:
            const Color(0xFF64748B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: SifeTheme.primaryRed,
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTÃO
  // ============================================================

  Widget _buildBotaoLogin() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              SifeTheme.primaryRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              SifeTheme.primaryRed.withOpacity(.55),
          elevation: 0,
          shadowColor:
              SifeTheme.primaryRed.withOpacity(.25),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(13),
          ),
        ),
        onPressed:
            _carregando ? null : _validarLogin,
        child: AnimatedSwitcher(
          duration:
              const Duration(milliseconds: 180),
          child: _carregando
              ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 21,
                  width: 21,
                  child:
                      CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.2,
                  ),
                )
              : Row(
                  key: const ValueKey('login'),
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Entrar no Sistema',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 19,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ============================================================
  // RODAPÉ
  // ============================================================

  Widget _buildRodape() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Icon(
          Icons.security_rounded,
          size: 15,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 7),
        Text(
          'Acesso seguro ao sistema escolar',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
