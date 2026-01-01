import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:futaba_ai_live/src/domain/ai_repository_interface.dart';
import 'package:futaba_ai_live/src/domain/ai_response.dart';
import 'package:futaba_ai_live/src/domain/expression.dart';
import 'package:futaba_ai_live/src/data/constants/prompts.dart';

class GeminiAiRepository implements IAiRepository {
  late final GenerativeModel _model;
  ChatSession? _chat;
  late final String _apiKey;

  GeminiAiRepository() {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }
    _apiKey = key;

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(Prompts.systemInstruction),
    );

    _chat = _model.startChat();
  }

  @override
  Future<AiResponse> sendMessage(String message) async {
    try {
      // Re-initialize if chat session is null for some reason
      _chat ??= _model.startChat();
      
      final response = await _chat!.sendMessage(Content.text(message));
      String? text = response.text;
      
      if (text == null) {
        // Check for safety block or other reasons
        final candidates = response.candidates;
        if (candidates.isNotEmpty) {
          final finishReason = candidates.first.finishReason;
          if (finishReason == FinishReason.safety) {
            return const AiResponse(
              message: 'すみません、安全フィルターにより回答を控えさせていただきます。入力内容を見直して再度お試しください。',
              expression: Expression.negativeLow,
            );
          }
        }
        throw Exception('Empty response from Gemini');
      }

      // Parse and filter expression tags: [expressionName]
      Expression expression = Expression.neutral;
      final tagMatch = RegExp(r'^\[([a-zA-Z]+)\]').firstMatch(text.trim());
      if (tagMatch != null) {
        final expressionName = tagMatch.group(1);
        if (expressionName != null) {
          expression = Expression.values.firstWhere(
            (e) => e.name == expressionName,
            orElse: () => Expression.neutral,
          );
        }
        // Remove the tag from the text
        text = text.replaceFirst(tagMatch.group(0)!, '').trim();
      }

      return AiResponse(
        message: text,
        expression: expression,
      );
    } catch (e) {
      debugPrint('Gemini API Error: $e');
      
      // If the chat session is in an error state, recreate it for the next message
      _chat = _model.startChat();
      
      String errorMessage = 'エラーが発生しました。時間を置いて再度お試しください。';
      final errorStr = e.toString();
      
      if (errorStr.contains('429')) {
        errorMessage = 'リクエストが多すぎます（429）。1分ほど待ってから再度お試しください。';
      } else if (errorStr.contains('403')) {
        errorMessage = 'アクセスが拒否されました（403）。APIキーの有効性や、モデルの利用権限を確認してください。';
      } else if (errorStr.contains('500')) {
        errorMessage = 'Geminiエンジンの内部エラー（500）です。少し待ってから再度お試しください。';
      }

      return AiResponse(
        message: '$errorMessage\n(Debug: ${errorStr.split('\n').first})',
        expression: Expression.negativeLow,
      );
    }
  }
}
