import 'package:flutter/material.dart';
import 'package:opensport/core/widgets/coming_soon.dart';

/// Enregistrement d'une activité GPS (étape 1 de la feuille de route).
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enregistrer')),
      body: const ComingSoon(
        icon: Icons.radio_button_checked_rounded,
        title: 'Enregistrement GPS',
        message:
            'Démarrer, mettre en pause et arrêter une course ou une '
            'sortie vélo, avec la carte, la distance et l\'allure en direct.',
        step: 'Étape 1 · GPS et carte',
      ),
    );
  }
}
