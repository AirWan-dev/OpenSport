import 'package:flutter/material.dart';
import 'package:opensport/core/theme/app_theme.dart';
import 'package:opensport/features/activities/data/demo_track.dart';

import 'flutter_map_vector_view.dart';
import 'maplibre_view.dart';

/// Écran temporaire de l'essai comparatif : la même carte avec les deux
/// bibliothèques candidates. À supprimer une fois le choix fait.
class MapLabScreen extends StatelessWidget {
  const MapLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final track = buildDemoTrack();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Labo carte'),
          bottom: const TabBar(
            indicatorColor: AppColors.accent,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [
              Tab(text: 'A · flutter_map'),
              Tab(text: 'B · MapLibre'),
            ],
          ),
        ),
        body: TabBarView(
          // Pas de balayage horizontal : il entrerait en conflit avec la carte.
          physics: const NeverScrollableScrollPhysics(),
          children: [
            FlutterMapVectorView(track: track),
            MapLibreView(track: track),
          ],
        ),
      ),
    );
  }
}
