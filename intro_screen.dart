import 'package:flutter/material.dart';
import 'next_screen.dart';
import 'fade_route.dart';
import '../widgets/intro_widgets.dart'; // Import your widgets

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              const AppLogo(),
              const SizedBox(height: 30),
              const WelcomeText(),
              const SizedBox(height: 40),
              ConnectButton(
                label: "Connect Gmail",
                onPressed: () {
                  Navigator.of(context).push(
                    FadeRoute(page: const NextScreen()),
                  );
                },
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 16),
              ConnectButton(
                label: "Connect Outlook",
                onPressed: () {
                  // TODO: Implement Outlook OAuth
                },
                color: Colors.deepPurpleAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                "We only scan emails with your permission. Your privacy is 100% safe.",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    FadeRoute(page: const NextScreen()),
                  );
                },
                child: const Text(
                  "Skip for now",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
