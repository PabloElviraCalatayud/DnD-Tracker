import 'package:flutter/material.dart';

import 'theme.dart';

/// La app tiene dos interfaces: la de PC (ventana ancha, ratón y teclado:
/// barra lateral, paneles divididos, tablas) y la de móvil (pantalla estrecha y
/// táctil: barra inferior, pantallas completas y hojas que suben desde abajo).
/// Una ventana de escritorio estrecha usa la de móvil.
const double desktopBreakpoint = 900;

bool isDesktopLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= desktopBreakpoint;

/// Lo que el armazón de escritorio ya muestra en su panel derecho, para que
/// las pantallas no lo repitan (p. ej. el tablero no pinta otro registro de tiradas).
class ShellPanels extends InheritedWidget {
  const ShellPanels({super.key, required this.rollsInSidePanel, required super.child});
  final bool rollsInSidePanel;

  static ShellPanels? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellPanels>();

  @override
  bool updateShouldNotify(ShellPanels old) => old.rollsInSidePanel != rollsInSidePanel;
}

/// Vista dividida de escritorio: lista a la izquierda y detalle a la derecha.
class MasterDetail extends StatelessWidget {
  const MasterDetail({
    super.key,
    required this.master,
    required this.detail,
    this.masterWidth = 420,
    this.emptyIcon = Icons.touch_app_outlined,
    this.emptyText = '',
  });

  final Widget master;
  final Widget? detail;
  final double masterWidth;
  final IconData emptyIcon;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: masterWidth, child: master),
        VerticalDivider(width: 1, color: AppColors.outlineSoft),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child:
                detail ??
                Center(
                  key: const ValueKey('vacío'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(emptyIcon, size: 40, color: AppColors.outline),
                      const SizedBox(height: 10),
                      Text(emptyText, style: TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
          ),
        ),
      ],
    );
  }
}

/// Fila de una lista de escritorio: se resalta al pasar el ratón y al estar elegida.
class HoverRow extends StatefulWidget {
  const HoverRow({super.key, required this.child, this.onTap, this.selected = false, this.onSecondaryTap});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final bool selected;

  @override
  State<HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? AppColors.primaryContainer.withValues(alpha: 0.75)
        : (_hover ? AppColors.surfaceHigh.withValues(alpha: 0.9) : Colors.transparent);
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onSecondaryTap: widget.onSecondaryTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: bg,
            border: Border(left: BorderSide(color: widget.selected ? AppColors.gold : Colors.transparent, width: 3)),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Cabecera de columnas de una tabla de escritorio.
class TableHeader extends StatelessWidget {
  const TableHeader({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 8)});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: AppColors.outlineSoft)),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        child: Row(children: children),
      ),
    );
  }
}
