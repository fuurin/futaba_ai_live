import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_session_state.freezed.dart';

@freezed
class LiveSessionState with _$LiveSessionState {
  const factory LiveSessionState.disconnected() = _Disconnected;
  const factory LiveSessionState.connecting() = _Connecting;
  const factory LiveSessionState.connected({@Default(false) bool isThinking}) = _Connected;
  const factory LiveSessionState.error(String message) = _Error;
}
