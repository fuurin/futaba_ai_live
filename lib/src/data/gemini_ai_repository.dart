import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:futaba_ai_live/src/domain/ai_repository_interface.dart';
import 'package:futaba_ai_live/src/domain/ai_response.dart';
import 'package:futaba_ai_live/src/domain/expression.dart';
import 'package:futaba_ai_live/src/data/constants/prompts.dart';

class GeminiAiRepository implements IAiRepository {
  late final GenerativeModel _model;
  late final ChatSession _chat;

  GeminiAiRepository() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(Prompts.systemInstruction),
    );

    _chat = _model.startChat();
  }

  @override
  Future<AiResponse> sendMessage(String message) async {
    try {
      final response = await _chat.sendMessage(Content.text(message));
      String? text = response.text;
      
      if (text == null) {
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
      // Log error internally if needed
      debugPrint('Gemini API Error: $e');
      return const AiResponse(
        message: 'すみません、エラーが発生しました。',
        expression: Expression.negativeLow,
      );
    }
  }
}
