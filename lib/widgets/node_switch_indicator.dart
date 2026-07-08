import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/node_provider.dart';

/// Индикатор переключения между узлами реестра.
class NodeSwitchIndicator extends StatelessWidget {
  const NodeSwitchIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NodeProvider>(
      builder: (context, provider, _) {
        if (!provider.isSwitching) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                provider.switchingMessage,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
