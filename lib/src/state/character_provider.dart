import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:futaba_ai_live/src/domain/expression.dart';

part 'character_provider.g.dart';

@riverpod
class Character extends _$Character {
  @override
  Expression build() {
    return Expression.neutral;
  }

  void updateExpression(Expression expression) {
    state = expression;
  }
}
