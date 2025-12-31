import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'message.freezed.dart';
part 'message.g.dart';

@freezed
@HiveType(typeId: 0)
class Message with _$Message {
  const factory Message({
    @HiveField(0) required String id,
    @HiveField(1) required String content,
    @HiveField(2) required bool isUser,
    @HiveField(3) required DateTime timestamp,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}
