import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/events_provider.dart';
import 'providers/votes_provider.dart';
import 'providers/online_provider.dart';
import 'providers/structure_provider.dart';
import 'providers/exchange_provider.dart';
import 'providers/candidacy_provider.dart';
import 'providers/node_provider.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const QuazarPassportApp());
}

class QuazarPassportApp extends StatelessWidget {
  const QuazarPassportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NodeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => EventsProvider()),
        ChangeNotifierProvider(create: (_) => VotesProvider()),
        ChangeNotifierProvider(create: (_) => OnlineProvider()),
        ChangeNotifierProvider(create: (_) => StructureProvider()),
        ChangeNotifierProvider(create: (_) => ExchangeProvider()),
        ChangeNotifierProvider(create: (_) => CandidacyProvider()),
      ],
      child: MaterialApp(
        title: 'Quazar Passport',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const _AppBootstrap(),
      ),
    );
  }
}

/// Сначала узлы, потом сессия — без гонки API-запросов на :8080.
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final nodes = context.read<NodeProvider>();
    final auth = context.read<AuthProvider>();

    await nodes.initialize();
    ApiService.syncActiveNode();
    await auth.initialize();

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Consumer<NodeProvider>(
        builder: (context, nodes, _) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (nodes.isSwitching) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        nodes.switchingMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoggedIn) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
