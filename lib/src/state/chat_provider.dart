import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:futaba_ai_live/src/domain/chat_repository_interface.dart';
import 'package:futaba_ai_live/src/domain/message.dart';

part 'chat_provider.g.dart';

@Riverpod(keepAlive: true)
IChatRepository chatRepository(Ref ref) {
  throw UnimplementedError('Provider was not overridden');
}

@riverpod
class Chat extends _$Chat {
  @override
  Future<List<Message>> build() async {
    final repository = ref.watch(chatRepositoryProvider);
    return repository.fetchMessages();
  }

  Future<void> sendMessage(String content) async {
    final repository = ref.read(chatRepositoryProvider);

    // User message
    final userMessage = Message(
      id: const Uuid().v4(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );

    await repository.saveMessage(userMessage);
    
    // Update local state optimistic or via refetch
    // For simplicity with AsyncValue, we can just invalidate/refetch, 
    // or update the state manually.
    // Manually updating state for better UX (avoid flickering)
    final previousState = state.value ?? [];
    state = AsyncData([...previousState, userMessage]);

    // Mock AI Reply
    _mockAiReply();
  }

  Future<void> _mockAiReply() async {
    await Future.delayed(const Duration(seconds: 1));
    
    final repository = ref.read(chatRepositoryProvider);
    
    final aiMessage = Message(
      id: const Uuid().v4(),
      content: 'AIからの返信です: ${DateTime.now().second}秒',
      isUser: false,
      timestamp: DateTime.now(),
    );

    await repository.saveMessage(aiMessage);
    
    final previousState = state.value ?? [];
    state = AsyncData([...previousState, aiMessage]);
  }

  Future<void> clearMessages() async {
    final repository = ref.read(chatRepositoryProvider);
    await repository.clearHistory();
    state = const AsyncData([]);
  }
}
