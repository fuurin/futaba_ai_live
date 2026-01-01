import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:futaba_ai_live/src/state/chat_provider.dart';
import 'package:futaba_ai_live/src/presentation/widgets/character_view.dart';
import 'package:futaba_ai_live/src/presentation/widgets/chat_view.dart';
import 'package:futaba_ai_live/src/state/live_session_provider.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveSessionState = ref.watch(liveSessionProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: 64, // Reduced from 80
        title: Image.asset(
          'assets/images/logo.png',
          height: 48, // Reduced from 64
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: liveSessionState.maybeWhen(
            connected: (_) => Container(
              height: 4.0,
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondary,
            ),
            connecting: () => const LinearProgressIndicator(),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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

