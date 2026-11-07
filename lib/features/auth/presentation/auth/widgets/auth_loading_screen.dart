import 'package:flutter/material.dart';

import 'auth_background.dart';

/// Shown while the session is restored at launch, between the native splash
/// and the first real screen: the login's orange background and a white
/// spinner, so the orange splash never flashes to white on the way.
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        children: [
          AuthGradientBackground(),
          Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}
