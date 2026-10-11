import 'package:flutter/material.dart';
import 'package:opensport/core/widgets/coming_soon.dart';

/// Séances de musculation (étape 2 de la feuille de route).
class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Muscu')),
      body: const ComingSoon(
        icon: Icons.fitness_center_rounded,
        title: 'Musculation',
        message:
            'Bibliothèque d\'exercices, séance en direct avec minuteur '
            'de repos, routines et records personnels.',
        step: 'Étape 2 · Musculation',
      ),
    );
  }
}
