import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            const Text(
              'Чат недоступен',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Текущая версия сервера Quazar Registry (0.7.0) '
              'не предоставляет WebSocket-эндпоинт для общего чата.\n\n'
              'Следите за событиями в ленте — там отображаются '
              'записи из блокчейна.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
