import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Icono de game-icons.net teñido con el color que se pida.
class GameIcon extends StatelessWidget {
  const GameIcon(this.name, {super.key, this.size = 24, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? AppColors.gold;
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
    );
  }
}

/// Fondo con la textura oscura, para que las pantallas no sean planas.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        image: DecorationImage(
          image: AssetImage('assets/images/parchment_dark.png'),
          repeat: ImageRepeat.repeat,
          opacity: 0.9,
        ),
      ),
      // Material transparente para que ListTile e InkWell pinten sus efectos
      // por encima de la textura.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Scaffold con el fondo texturizado.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.titleWidget,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.bottomNavigationBar,
    this.leading,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;
  final Widget? bottomNavigationBar;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: (title != null || titleWidget != null)
          ? AppBar(title: titleWidget ?? Text(title!), actions: actions, bottom: bottom, leading: leading)
          : null,
      body: Backdrop(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Tarjeta con título para agrupar bloques de información.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.icon, this.trailing, required this.child, this.padding});

  final String? title;
  final String? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    if (icon != null) ...[GameIcon(icon!, size: 20), Gap.s],
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16.5, color: AppColors.gold),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Recuadro de estadística: valor grande y etiqueta.
class StatBox extends StatelessWidget {
  const StatBox({
    super.key,
    required this.label,
    required this.value,
    this.valueWidget,
    this.sub,
    this.onTap,
    this.highlight = false,
    this.width = 86,
  });

  final String label;
  final String value;
  final Widget? valueWidget;
  final String? sub;
  final VoidCallback? onTap;
  final bool highlight;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: highlight
          ? AppColors.primaryContainer.withValues(alpha: 0.5)
          : AppColors.surfaceHigh.withValues(alpha: 0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: highlight ? AppColors.goldSoft : AppColors.outlineSoft),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child:
                      valueWidget ??
                      Text(
                        value,
                        // Cinzel para cifras; con letras (unidades, monedas) la fuente de texto se lee mejor.
                        style: RegExp(r'^[−+\-]?[0-9/]+$').hasMatch(value)
                            ? t.headlineSmall?.copyWith(fontSize: 22, color: AppColors.parchment)
                            : t.titleLarge?.copyWith(
                                fontFamily: 'AlegreyaSans',
                                fontWeight: FontWeight.w700,
                                fontSize: 19,
                                color: AppColors.parchment,
                              ),
                      ),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    style: t.labelSmall?.copyWith(color: AppColors.gold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de puntos de golpe.
class HpBar extends StatelessWidget {
  const HpBar({super.key, required this.current, required this.max, this.temp = 0, this.height = 10});

  final int current;
  final int max;
  final int temp;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    final tempRatio = max <= 0 ? 0.0 : (temp / max).clamp(0.0, 1.0 - ratio);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: AppColors.outlineSoft),
            FractionallySizedBox(
              widthFactor: ratio,
              child: Container(color: AppColors.hpColor(ratio)),
            ),
            if (tempRatio > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio + tempRatio,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: tempRatio / (ratio + tempRatio),
                      child: Container(color: AppColors.arcane),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final String icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(icon, size: 72, color: AppColors.goldSoft),
            Gap.m,
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              Gap.s,
              Text(
                message!,
                style: t.bodyMedium?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[Gap.l, action!],
          ],
        ),
      ),
    );
  }
}

/// Selector numérico con botones − y +.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 9999,
    this.step = 1,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 32.0 : 40.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.remove),
            onPressed: value - step >= min ? () => onChanged(value - step) : null,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 28),
          child: Text('$value', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          width: size,
          height: size,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add),
            onPressed: value + step <= max ? () => onChanged(value + step) : null,
          ),
        ),
      ],
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = AppColors.gold, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 3)],
          Text(
            text,
            style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.onChanged, this.hint = 'Buscar…', this.controller});
  final ValueChanged<String> onChanged;
  final String hint;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: hint),
      onChanged: onChanged,
    );
  }
}

/// Texto con formato Markdown sencillo (las descripciones del SRD lo usan).
class RichDescription extends StatelessWidget {
  const RichDescription(this.text, {super.key, this.selectable = true});
  final String text;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MarkdownBody(
      data: text,
      selectable: selectable,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: t.bodyMedium,
        strong: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.parchment),
        h1: t.titleLarge,
        h2: t.titleLarge?.copyWith(fontSize: 17),
        h3: t.titleMedium?.copyWith(color: AppColors.gold),
        h4: t.titleSmall?.copyWith(color: AppColors.gold),
        tableBorder: TableBorder.all(color: AppColors.outline),
        tableHead: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold),
        tableBody: t.bodySmall?.copyWith(color: AppColors.parchment),
        blockquoteDecoration: const BoxDecoration(
          color: AppColors.surfaceHigh,
          border: Border(left: BorderSide(color: AppColors.goldSoft, width: 3)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Diálogos

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? AppColors.secondaryDark : null));
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String ok = 'Aceptar',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.crimson) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> promptText(
  BuildContext context,
  String title, {
  String initial = '',
  String? hint,
  bool multiline = false,
  String ok = 'Guardar',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: multiline ? 4 : 1,
          maxLines: multiline ? 12 : 1,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: multiline ? null : (v) => Navigator.pop(ctx, v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(ok)),
      ],
    ),
  );
}

/// Pide un número (con signo opcional). Útil para daño/curación.
Future<int?> promptNumber(
  BuildContext context,
  String title, {
  int? initial,
  String? hint,
  bool allowNegative = false,
}) {
  final controller = TextEditingController(text: initial?.toString() ?? '');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 300,
        child: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(signed: allowNegative),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(allowNegative ? r'[-0-9]' : r'[0-9]'))],
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)), child: const Text('Aceptar')),
      ],
    ),
  );
}

Future<void> copyToClipboard(BuildContext context, String text, {String message = 'Copiado'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showSnack(context, message);
}
