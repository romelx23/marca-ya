import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/auth_controller.dart';

/// Datos del empleado con sesión activa. Solo lectura: los cambios los hace RRHH.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(authControllerProvider).valueOrNull?.employee;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: employee == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: _InitialsAvatar(employee.fullName)),
                const SizedBox(height: 16),
                Text(
                  employee.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  employee.roleLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.textMuted),
                ),
                const SizedBox(height: 28),
                _InfoRow(
                  icon: Icons.mail_outline,
                  label: 'Correo',
                  value: employee.email,
                ),
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Documento',
                  value: employee.documentId ?? 'Sin documento registrado',
                ),
                _InfoRow(
                  icon: Icons.work_outline,
                  label: 'Rol',
                  value: employee.roleLabel,
                ),
              ],
            ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brandGradient,
      ),
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.cardTop, p.cardBottom],
          ),
          border: Border.all(color: p.border),
          boxShadow: p.cardShadow,
        ),
        child: Row(
          children: [
            Icon(icon, color: p.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: p.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
