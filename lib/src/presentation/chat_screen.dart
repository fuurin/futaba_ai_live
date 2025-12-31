import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:futaba_ai_live/src/state/chat_provider.dart';
import 'package:futaba_ai_live/src/presentation/widgets/character_view.dart';
import 'package:futaba_ai_live/src/presentation/widgets/chat_view.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Futaba AI Live'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('履歴の削除'),
                    content: const Text('本当にすべてのメッセージを削除しますか？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('キャンセル'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('削除'),
                      ),
                    ],
                  );
                },
              );

              if (confirmed == true) {
                await ref.read(chatProvider.notifier).clearMessages();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Expanded(
            flex: 1,
            child: CharacterView(),
          ),
          const Divider(height: 1),
          const Expanded(
            flex: 1,
            child: ChatView(),
          ),
        ],
      ),
    );
  }
}

