import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/events_provider.dart';
import '../providers/votes_provider.dart';
import '../providers/online_provider.dart';
import '../providers/exchange_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/online_indicator.dart';
import '../widgets/node_switch_indicator.dart';
import 'events_screen.dart';
import 'voting_screen.dart';
import 'passport_screen.dart';
import 'exchange_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    EventsScreen(),
    ChatScreen(),
    VotingScreen(),
    PassportScreen(),
    ExchangeScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = [
    'Лента событий',
    'Чат',
    'Голосования',
    'Паспорт',
    'Биржа',
    'Настройки',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<EventsProvider>(context, listen: false).loadEvents(auth);
      Provider.of<VotesProvider>(context, listen: false).loadVotes(auth);
      Provider.of<OnlineProvider>(context, listen: false).startAutoRefresh();
    });
  }

  @override
  void dispose() {
    Provider.of<OnlineProvider>(context, listen: false).stopAutoRefresh();
    super.dispose();
  }

  void _refreshCurrentTab() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    switch (_currentIndex) {
      case 0:
        Provider.of<EventsProvider>(context, listen: false).loadEvents(auth);
        break;
      case 1:
        Provider.of<ChatProvider>(context, listen: false).loadMessages(auth);
        break;
      case 2:
        Provider.of<VotesProvider>(context, listen: false).loadVotes(auth);
        break;
      case 4:
        Provider.of<ExchangeProvider>(context, listen: false).loadAll(auth);
        break;
    }
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход из системы'),
        content: Text(
          auth.useBiometrics
              ? 'Вы выйдете из аккаунта, но сможете войти снова по отпечатку.'
              : 'Вы уверены, что хотите выйти?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await Provider.of<AuthProvider>(context, listen: false).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        actions: [
          const NodeSwitchIndicator(),
          const OnlineIndicator(),
          const SizedBox(width: 8),
          if (_currentIndex == 0 ||
              _currentIndex == 1 ||
              _currentIndex == 2 ||
              _currentIndex == 4)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshCurrentTab,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 4) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            Provider.of<ExchangeProvider>(context, listen: false).loadAll(auth);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'События',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Чат',
          ),
          NavigationDestination(
            icon: Icon(Icons.how_to_vote),
            label: 'Голосования',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code),
            label: 'Паспорт',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront),
            label: 'Биржа',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}
