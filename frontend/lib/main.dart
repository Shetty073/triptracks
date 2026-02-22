import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme.dart';
import 'package:frontend/features/auth/screens/auth_screen.dart';
import 'package:frontend/core/auth_provider.dart';
import 'package:frontend/features/feed/screens/home_feed_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TripTracksApp()));
}

class TripTracksApp extends ConsumerWidget {
  const TripTracksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'TripTracks',
      theme: TripTracksTheme.lightTheme,
      darkTheme: TripTracksTheme.darkTheme,
      themeMode: ThemeMode.system, // Modern apps respect system settings
      debugShowCheckedModeBanner: false,
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const HomeFeedScreen();
          }
          return const AuthScreen();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, s) => const AuthScreen(),
      ),
    );
  }
}
