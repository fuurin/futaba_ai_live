import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:futaba_ai_live/src/domain/live_session_state.dart';
import 'package:futaba_ai_live/src/domain/expression.dart';
import 'package:futaba_ai_live/src/data/live_session_repository.dart';
import 'package:futaba_ai_live/src/state/chat_provider.dart';
import 'package:futaba_ai_live/src/state/character_provider.dart';

part 'live_session_provider.g.dart';

@Riverpod(keepAlive: true)
LiveSessionRepository liveSessionRepository(Ref ref) {
  return LiveSessionRepository();
}

@riverpod
class LiveSession extends _$LiveSession {
  @override
  LiveSessionState build() {
    return const LiveSessionState.disconnected();
  }

  Future<void> toggleSession() async {
    final repository = ref.read(liveSessionRepositoryProvider);
    bool shouldAppend = false;

    state.when(
      disconnected: () async {
        state = const LiveSessionState.connecting();
        try {
          await repository.connect(
            onTranscriptionReceived: (text, isUser) {
              ref.read(chatProvider.notifier).addLiveMessage(
                text, 
                isUser: isUser, 
                append: shouldAppend,
              );
              shouldAppend = true; // After the first piece, start appending
            },
            onTurnComplete: () {
              shouldAppend = false; // Reset for the next turn
            },
            onExpressionChanged: (expressionName) {
              try {
                final expression = Expression.values.firstWhere(
                  (e) => e.name == expressionName,
                  orElse: () => Expression.neutral,
                );
                ref.read(characterProvider.notifier).updateExpression(expression);
              } catch(e) {
                // Ignore unknown expressions
              }
            },
          );
          state = const LiveSessionState.connected();
        } catch (e) {
          state = LiveSessionState.error(e.toString());
        }
      },
      connecting: () {
        // Do nothing while connecting
      },
      connected: () async {
        await repository.disconnect();
        state = const LiveSessionState.disconnected();
      },
      error: (_) async {
         // Retry connection
        state = const LiveSessionState.connecting();
        try {
          await repository.connect(
            onTranscriptionReceived: (text, isUser) {
              ref.read(chatProvider.notifier).addLiveMessage(
                text, 
                isUser: isUser, 
                append: shouldAppend,
              );
              shouldAppend = true;
            },
            onTurnComplete: () {
              shouldAppend = false;
            },
            onExpressionChanged: (expressionName) {
              try {
                final expression = Expression.values.firstWhere(
                  (e) => e.name == expressionName,
                  orElse: () => Expression.neutral,
                );
                ref.read(characterProvider.notifier).updateExpression(expression);
              } catch(e) {
                // Ignore unknown expressions
              }
            },
          );
          state = const LiveSessionState.connected();
        } catch (e) {
          state = LiveSessionState.error(e.toString());
        }
      },
    );
  }
}
