import 'package:hive_flutter/hive_flutter.dart';
import 'package:futaba_ai_live/src/domain/chat_repository_interface.dart';
import 'package:futaba_ai_live/src/domain/message.dart';

class HiveChatRepository implements IChatRepository {
  final Box<Message> _box;

  HiveChatRepository(this._box);

  @override
  Future<List<Message>> fetchMessages() async {
    // Hiveのキー順（追加順）で取得し、リストとして返す
    return _box.values.toList();
  }

  @override
  Future<void> saveMessage(Message message) async {
    await _box.add(message);
  }

  @override
  Future<void> clearHistory() async {
    await _box.clear();
  }
}
