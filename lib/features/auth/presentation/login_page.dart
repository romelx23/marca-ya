import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: 500.ms,
  );
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Ingresa tu correo y clave');
      _shake.forward(from: 0);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref
        .read(authControllerProvider.notifier)
        .login(_email.text, _password.text);
    if (!mounted) return;
    // Si el login fue correcto, la app cambia de pantalla sola.
    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      _shake.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.1,
            colors: [p.glow, p.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child:
                    Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [AppColors.indigo, AppColors.mint],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.indigo.withValues(
                                        alpha: .45,
                                      ),
                                      blurRadius: 32,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.fingerprint,
                                  size: 40,
                                  color: Colors.black87,
                                ),
                              ),
                            ).animate().scale(
                              duration: Motion.slow,
                              curve: Curves.elasticOut,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                                  'MarcaYa',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 150.ms, duration: Motion.medium)
                                .slideY(begin: .3, curve: Motion.curve),
                            const SizedBox(height: 4),
                            Text(
                              'Control de asistencia',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: p.textMuted),
                            ).animate().fadeIn(
                              delay: 250.ms,
                              duration: Motion.medium,
                            ),
                            const SizedBox(height: 32),
                            AutofillGroup(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                        key: const Key('email'),
                                        controller: _email,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        autofillHints: const [
                                          AutofillHints.username,
                                        ],
                                        textInputAction: TextInputAction.next,
                                        decoration: _decoration(
                                          p,
                                          'Correo',
                                          Icons.mail_outline,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      TextField(
                                        key: const Key('password'),
                                        controller: _password,
                                        obscureText: _obscure,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        onSubmitted: (_) => _submit(),
                                        decoration:
                                            _decoration(
                                              p,
                                              'Clave',
                                              Icons.lock_outline,
                                            ).copyWith(
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _obscure
                                                      ? Icons.visibility_off
                                                      : Icons.visibility,
                                                ),
                                                onPressed: () => setState(
                                                  () => _obscure = !_obscure,
                                                ),
                                              ),
                                            ),
                                      ),
                                    ],
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 350.ms, duration: Motion.medium)
                                .slideY(begin: .15),
                            AnimatedSize(
                              duration: Motion.fast,
                              child: _error == null
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Text(
                                        _error!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFFFF6B6B),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 20),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF8B84FF),
                                    Color(0xFF5B52F0),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.indigo.withValues(
                                      alpha: .45,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: FilledButton(
                                key: const Key('login-button'),
                                onPressed: _loading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: AnimatedSwitcher(
                                  duration: Motion.fast,
                                  child: _loading
                                      ? const SizedBox(
                                          key: ValueKey('spin'),
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Ingresar',
                                          key: ValueKey('label'),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ).animate().fadeIn(
                              delay: 450.ms,
                              duration: Motion.medium,
                            ),
                          ],
                        )
                        .animate(controller: _shake, autoPlay: false)
                        .shakeX(hz: 5, amount: 8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(AppPalette p, String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: p.fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.indigo, width: 1.5),
        ),
      );
}
