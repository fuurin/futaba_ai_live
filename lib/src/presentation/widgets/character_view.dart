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

    return Container(
      color: Theme.of(context).colorScheme.surface,
      width: double.infinity,
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover, // Fill entire space (best for square images on phone)
        alignment: Alignment.topCenter, // Keep face visible
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
    );
  }
}
