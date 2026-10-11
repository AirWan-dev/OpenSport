import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/demo_track.dart';
import 'screens/activity_map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const OpenSportApp());
}

class OpenSportApp extends StatelessWidget {
  const OpenSportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenSport',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFFC5200),
      ),
      home: ActivityMapScreen(track: buildDemoTrack()),
    );
  }
}
