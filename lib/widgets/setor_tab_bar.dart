import 'package:flutter/material.dart';
import '../app_theme.dart';

class SetorTabBar extends StatelessWidget {
  final List<String> setores;
  final String setorAtivo;
  final ValueChanged<String> onSetorChanged;
  final bool isTv;

  const SetorTabBar({
    super.key,
    required this.setores,
    required this.setorAtivo,
    required this.onSetorChanged,
    this.isTv = false,
  });

  @override
  Widget build(BuildContext context) {
    if (setores.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: setores.map((setor) {
          final isAtivo = setor == setorAtivo;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSetorChanged(setor),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                  horizontal: isTv ? 24 : 16,
                  vertical: isTv ? 12 : 8,
                ),
                decoration: BoxDecoration(
                  color: isAtivo ? AppTheme.accentBlue.withOpacity(0.15) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAtivo ? AppTheme.accentBlue : AppTheme.border,
                    width: isAtivo ? 1.5 : 1,
                  ),
                ),
                child: Text(setor, style: TextStyle(
                  fontSize: isTv ? 16 : 13,
                  fontWeight: isAtivo ? FontWeight.w600 : FontWeight.w400,
                  color: isAtivo ? AppTheme.accentBlue : AppTheme.textSecondary,
                  fontFamily: 'Inter',
                )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
