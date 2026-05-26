import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'providers/service_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-initialize SharedPreferences for Riverpod dependency injection
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SallahFlexApp(),
    ),
  );
}
