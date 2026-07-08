import 'package:flutter/material.dart';

class ReferendumsScreen extends StatelessWidget {
  const ReferendumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Активные референдумы'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Здесь будет список активных референдумов и сбор подписей.\n'
            'Пока — заглушка.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
