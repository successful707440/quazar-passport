import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/node_provider.dart';
import '../providers/online_provider.dart';

class OnlineIndicator extends StatelessWidget {
  const OnlineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<OnlineProvider, NodeProvider>(
      builder: (context, online, nodes, child) {
        if (online.isLoading || nodes.isSwitching) {
          return Tooltip(
            message: nodes.switchingMessage,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  nodes.isSwitching ? 'Поиск узла' : '…',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          );
        }

        final allOffline = nodes.allNodesOffline || !online.serverOnline;

        return Tooltip(
          message: online.serverOnline
              ? 'Узел ${nodes.nodeLabel} · блоков: ${online.blocksCount}'
              : allOffline
                  ? 'Все узлы недоступны'
                  : 'Узел ${nodes.nodeLabel} недоступен',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: online.serverOnline
                      ? Colors.green.shade300
                      : Colors.red.shade300,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                online.serverOnline
                    ? '${online.blocksCount} блок.'
                    : 'offline',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
