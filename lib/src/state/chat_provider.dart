import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:futaba_ai_live/src/domain/chat_repository_interface.dart';
import 'package:futaba_ai_live/src/domain/message.dart';
import 'package:futaba_ai_live/src/domain/ai_repository_interface.dart';
import 'package:futaba_ai_live/src/data/gemini_ai_repository.dart';
import 'package:futaba_ai_live/src/state/character_provider.dart';
import 'package:futaba_ai_live/src/domain/expression.dart';
import 'package:flutter/foundation.dart';

part 'chat_provider.g.dart';

@Riverpod(keepAlive: true)
IChatRepository chatRepository(Ref ref) {
  throw UnimplementedError('Provider was not overridden');
}

@Riverpod(keepAlive: true)
IAiRepository aiRepository(Ref ref) {
  return GeminiAiRepository();
}

@riverpod
class Chat extends _$Chat {
  @override
  Future<List<Message>> build() async {
    final repository = ref.watch(chatRepositoryProvider);
    // TODO: Need to persist last expression? For now, reset to neutral on app launch.
    return repository.fetchMessages();
  }

  Future<void> sendMessage(String content) async {
    final repository = ref.read(chatRepositoryProvider);
    final aiRepository = ref.read(aiRepositoryProvider);

    // User message
    final userMessage = Message(
      id: const Uuid().v4(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );

    await repository.saveMessage(userMessage);

    final previousState = state.value ?? [];
    state = AsyncData([...previousState, userMessage]);

    // AI Reply
    try {
      final response = await aiRepository.sendMessage(content);
      
      final aiMessage = Message(
        id: const Uuid().v4(),
        content: response.message,
        isUser: false,
        timestamp: DateTime.now(),
      );

      await repository.saveMessage(aiMessage);
      
      // Update Chat State
      final currentState = state.value ?? [];
      state = AsyncData([...currentState, aiMessage]);

      // Update Character Expression
      ref.read(characterProvider.notifier).updateExpression(response.expression);

    } catch (e) {
       // Log error or show snackbar (handled in UI via state listener if needed)
       // For now, the repository returns an error message as fallback
       debugPrint('Error in sendMessage: $e');
    }
  }

  Future<void> addLiveMessage(String content, {required bool isUser, bool append = false}) async {
    final repository = ref.read(chatRepositoryProvider);
    final currentState = state.value ?? [];

    if (append && currentState.isNotEmpty) {
      final lastMessage = currentState.last;
      if (lastMessage.isUser == isUser) {
        final updatedMessage = lastMessage.copyWith(
          content: lastMessage.content + content,
        );
        
        await repository.saveMessage(updatedMessage);
        
        state = AsyncData([
          ...currentState.sublist(0, currentState.length - 1),
          updatedMessage,
        ]);
        return;
      }
    }
    
    final message = Message(
      id: const Uuid().v4(),
      content: content,
      isUser: isUser,
      timestamp: DateTime.now(),
    );

    await repository.saveMessage(message);
    state = AsyncData([...currentState, message]);
  }

  Future<void> clearMessages() async {
    final repository = ref.read(chatRepositoryProvider);
    await repository.clearHistory();
    state = const AsyncData([]);
    // Reset expression
    ref.read(characterProvider.notifier).updateExpression(Expression.neutral);
  }
}
