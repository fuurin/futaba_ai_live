import 'package:futaba_ai_live/src/domain/ai_response.dart';

abstract interface class IAiRepository {
  Future<AiResponse> sendMessage(String message);
}
