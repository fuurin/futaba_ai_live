import 'package:futaba_ai_live/src/domain/expression.dart';

class AiResponse {
  final String message;
  final Expression expression;

  const AiResponse({
    required this.message,
    required this.expression,
  });
}
