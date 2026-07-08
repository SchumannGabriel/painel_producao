import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'app_theme.dart';
import 'screens/painel_producao_screen.dart';
import 'services/snapshot_service.dart';

final _snapshotService = SnapshotService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Roda no painel (TV) — fica aberto o dia todo.
  // Protegido para NUNCA tocar nos snapshots de apontamento (09:30, 11:30, 15:00, 16:30).
  _snapshotService.iniciar();

  runApp(const PainelApp());
}

class PainelApp extends StatefulWidget {
  const PainelApp({super.key});

  @override
  State<PainelApp> createState() => _PainelAppState();
}

class _PainelAppState extends State<PainelApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _snapshotService.parar();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _snapshotService.iniciar();
    } else if (state == AppLifecycleState.paused) {
      _snapshotService.parar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Painel de Produção',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const PainelProducaoScreen(),
    );
  }
}
