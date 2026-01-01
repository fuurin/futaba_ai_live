import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:futaba_ai_live/src/state/character_provider.dart';
import 'package:futaba_ai_live/src/domain/expression.dart';

class CharacterView extends ConsumerWidget {
  const CharacterView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expression = ref.watch(characterProvider);

    String imagePath;
    switch (expression) {
      case Expression.neutral:
        imagePath = 'assets/images/face_positiveLow.jpg';
        break;
      case Expression.positiveLow:
        imagePath = 'assets/images/face_positiveLow.jpg';
        break;
      case Expression.positiveMid:
        imagePath = 'assets/images/face_positiveMid.jpg';
        break;
      case Expression.positiveHigh:
        imagePath = 'assets/images/face_positiveHigh.jpg';
        break;
      case Expression.negativeLow:
        imagePath = 'assets/images/face_negativeLow.jpg';
        break;
      case Expression.negativeMid:
        imagePath = 'assets/images/face_negativeMid.jpg';
        break;
      case Expression.negativeHigh:
        imagePath = 'assets/images/face_negativeHigh.jpg';
        break;
    }

    return SizedBox.expand(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            return Stack(
              alignment: Alignment.topCenter,
              fit: StackFit.expand,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Image.asset(
            imagePath,
            key: ValueKey<String>(imagePath), // Critical for triggering animation
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    Text('Image not found: $imagePath'),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
