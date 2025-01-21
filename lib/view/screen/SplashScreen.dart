import 'package:flutter/material.dart';
import '/main.dart';

import 'homeScreen.dart';
import 'ouathUser/welcome.dart'; // Assuming your main file is named 'main.dart'

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate a delay for the splash screen
    Future.delayed(const Duration(seconds: 2), () {
      supabase.auth.currentSession == null
          ? Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (c) => const WelcomePage()))
          : Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (c) => const HomeScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'lib/util/images/vistalogo.png', // Replace with your actual logo image path
              height: 150,
              width: 150,
            ),
            const SizedBox(height: 20),
            const Text(
              'Vista Note', // Your app name
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
