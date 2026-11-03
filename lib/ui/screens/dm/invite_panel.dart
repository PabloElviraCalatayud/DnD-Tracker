import 'package:flutter/material.dart';

import '../../../engine/commands.dart';
import '../../../net/network_info.dart';
import '../../../net/transport.dart';
import '../../../state/host_session.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Panel para invitar jugadores: código, direcciones y mensaje para compartir.
class InvitePanel extends StatelessWidget {
  const InvitePanel({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context) as HostSession;
    final t = Theme.of(context).textTheme;
    final invite = s.invite;
    return SectionCard(
      title: 'Invitar jugadores',
      icon: 'scroll_quill',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Código: ', style: t.titleMedium),
              SelectableText(
                s.campaign.joinCode,
                style: t.headlineSmall?.copyWith(color: AppColors.gold, letterSpacing: 4),
              ),
              const Spacer(),
              if (!compact)
                IconButton(
                  tooltip: 'Generar otro código',
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    final ok = await confirm(
                      context,
                      'Nuevo código',
                      'Los jugadores que ya están en la partida seguirán entrando. Sólo cambia para los nuevos.',
                    );
                    if (ok) await s.send(Command.regenerateJoinCode());
                  },
                ),
            ],
          ),
          Gap.s,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Copiar invitación'),
                onPressed: () => copyToClipboard(
                  context,
                  invite.shareText(),
                  message: 'Invitación copiada: pégala en vuestro grupo de WhatsApp',
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Sólo el código DNDT1'),
                onPressed: () => copyToClipboard(context, invite.encode()),
              ),
            ],
          ),
          Gap.m,
          if (!s.serverRunning)
            Text(s.statusMessage, style: t.bodyMedium?.copyWith(color: AppColors.danger))
          else ...[
            Text('Los jugadores pueden conectarse a:', style: t.bodySmall),
            for (final a in s.addresses)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(a.kind == AddressKind.vpn ? Icons.vpn_lock : Icons.wifi, size: 16, color: AppColors.gold),
                    Gap.s,
                    SelectableText('${a.address}:${s.port}', style: t.titleSmall),
                    Gap.s,
                    Flexible(
                      child: Text(
                        '${a.kind.label} · ${a.interfaceName}',
                        style: t.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (s.addresses.isEmpty) Text('No se detectan redes. ¿Estás conectado a una wifi?', style: t.bodySmall),
            if (s.relayUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.public,
                      size: 16,
                      color: s.relayState == RelayState.online ? AppColors.success : AppColors.warning,
                    ),
                    Gap.s,
                    Expanded(
                      child: Text(
                        'Relay ${s.relayUrl}: ${switch (s.relayState) {
                          RelayState.online => 'conectado',
                          RelayState.connecting => 'conectando…',
                          RelayState.error => 'error (${s.relayError})',
                          RelayState.disabled => 'desactivado',
                        }}',
                        style: t.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
