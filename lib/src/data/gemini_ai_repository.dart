import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:futaba_ai_live/src/domain/ai_repository_interface.dart';
import 'package:futaba_ai_live/src/domain/ai_response.dart';
import 'package:futaba_ai_live/src/domain/expression.dart';

class GeminiAiRepository implements IAiRepository {
  late final GenerativeModel _model;
  late final ChatSession _chat;

  GeminiAiRepository() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'message': Schema.string(),
            'expression': Schema.enumString(
              enumValues: Expression.values.map((e) => e.name).toList(),
            ),
          },
          requiredProperties: ['message', 'expression'],
        ),
      ),
      systemInstruction: Content.system('''
You are a friendly AI character. Respond to the user's message in Japanese.
Also, determine the appropriate facial expression for your response from the given list.
Return the response in JSON format.
      '''),
    );

    _chat = _model.startChat();
  }

  @override
  Future<AiResponse> sendMessage(String message) async {
    try {
      final response = await _chat.sendMessage(Content.text(message));
      final text = response.text;
      
      if (text == null) {
        throw Exception('Empty response from Gemini');
      }

      final json = jsonDecode(text) as Map<String, dynamic>;
      final responseMessage = json['message'] as String;
      final expressionName = json['expression'] as String;
      
      final expression = Expression.values.firstWhere(
        (e) => e.name == expressionName,
        orElse: () => Expression.neutral,
      );

      return AiResponse(
        message: responseMessage,
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
