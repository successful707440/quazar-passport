import 'package:flutter/material.dart';

class InitiativesScreen extends StatelessWidget {
  const InitiativesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список инициатив'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Здесь будет список инициатив Совета граждан.\n'
            'Пока — заглушка.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
