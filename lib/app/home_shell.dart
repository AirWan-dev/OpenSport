import 'package:flutter/material.dart';
import 'package:opensport/features/activities/screens/feed_screen.dart';
import 'package:opensport/features/profile/profile_screen.dart';
import 'package:opensport/features/record/record_screen.dart';
import 'package:opensport/features/workouts/workouts_screen.dart';

/// Squelette de l'application : quatre onglets en bas de l'écran.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    FeedScreen(),
    RecordScreen(),
    WorkoutsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack garde chaque onglet en vie (position de défilement...).
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Fil',
          ),
          NavigationDestination(
            icon: Icon(Icons.radio_button_checked_rounded),
            label: 'Enregistrer',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_rounded),
            label: 'Muscu',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
