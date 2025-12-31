import 'package:futaba_ai_live/src/domain/message.dart';

abstract interface class IChatRepository {
  Future<List<Message>> fetchMessages();
  Future<void> saveMessage(Message message);
  Future<void> clearHistory();
}
