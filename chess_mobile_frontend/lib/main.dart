import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'state/chess_game_controller.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

/// PUBLIC_INTERFACE
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChessGameController(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Smart Chess',
        theme: AppTheme.light(),
        home: const HomeScreen(),
      ),
    );
  }
}
