import 'package:hive_flutter/hive_flutter.dart';
import 'package:futaba_ai_live/src/domain/chat_repository_interface.dart';
import 'package:futaba_ai_live/src/domain/message.dart';

class HiveChatRepository implements IChatRepository {
  final Box<Message> _box;

  HiveChatRepository(this._box);

  @override
  Future<List<Message>> fetchMessages() async {
    final messages = _box.values.toList();
    // タイムスタンプ順にソートして返す
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  @override
  Future<void> saveMessage(Message message) async {
    await _box.put(message.id, message);
  }

  @override
  Future<void> clearHistory() async {
    await _box.clear();
  }
}
