import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/attendance/presentation/home_page.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';

void main() => runApp(const ProviderScope(child: MarcaYaApp()));

class MarcaYaApp extends ConsumerWidget {
  const MarcaYaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    return MaterialApp(
      title: 'MarcaYa',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ref.watch(themeModeProvider),
      home: AnimatedSwitcher(
        duration: Motion.medium,
        child: session.when(
          loading: () => const Scaffold(
            key: ValueKey('splash'),
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => const LoginPage(key: ValueKey('login')),
          data: (s) => s == null
              ? const LoginPage(key: ValueKey('login'))
              : HomePage(key: ValueKey(s.employee.id)),
        ),
      ),
    );
  }
}
