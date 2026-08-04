import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'controllers/frequencia_controller.dart';
import 'views/login_page.dart';
import 'views/totem_facial_page.dart';
import 'views/cadastro_rosto_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FrequenciaController()),
      ],
      child: const SifeApp(),
    ),
  );
}

class SifeApp extends StatelessWidget {
  const SifeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIFE Mobile',
      theme: ThemeData(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      // Rota inicial do aplicativo
      initialRoute: '/',
      
      // Mapeamento de rotas para navegação limpa
      routes: {
        '/': (context) => const LoginPage(),
        '/totem': (context) => const TotemFacialPage(),
        '/cadastro-rosto': (context) => const CadastroRostoPage(),
      },
    );
  }
}