import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo.dart';
import '../../data/storage.dart';
import '../../domain/campaign.dart';
import '../../state/client_session.dart';
import '../../state/host_session.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'campaign_shell.dart';
import 'create_campaign_screen.dart';
import 'join_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final hosted = ref.watch(hostedCampaignsProvider);
    final joined = ref.watch(joinedCampaignsProvider);
    final t = Theme.of(context).textTheme;

    return AppScaffold(
      titleWidget: Row(
        children: [
          const GameIcon('d20', size: 26),
          Gap.s,
          Text(
            'DnD Tracker',
            style: t.titleLarge?.copyWith(fontFamily: 'CinzelDecorative', color: AppColors.gold),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Perfil y ajustes',
          icon: const Icon(Icons.person_outline),
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
        ),
        IconButton(
          tooltip: 'Créditos y licencias',
          icon: const Icon(Icons.info_outline),
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(hostedCampaignsProvider);
          ref.invalidate(joinedCampaignsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Saludos, ${profile.displayName}', style: t.headlineSmall),
                    Text('¿Diriges o juegas hoy?', style: t.bodyLarge?.copyWith(color: AppColors.muted)),
                    Gap.m,
                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth > 560;
                        final cards = [
                          _ActionCard(
                            icon: 'crowned_skull',
                            title: 'Crear partida',
                            subtitle: 'Serás el máster y el anfitrión',
                            color: AppColors.gold,
                            onTap: () => _create(context, ref),
                          ),
                          _ActionCard(
                            icon: 'rally',
                            title: 'Unirse a partida',
                            subtitle: 'Con la invitación del máster',
                            color: AppColors.arcane,
                            onTap: () => _join(context, ref),
                          ),
                        ];
                        return wide
                            ? Row(
                                children: [
                                  Expanded(child: cards[0]),
                                  Gap.m,
                                  Expanded(child: cards[1]),
                                ],
                              )
                            : Column(children: [cards[0], Gap.s, cards[1]]);
                      },
                    ),
                    Gap.l,
                    _Header(
                      icon: 'crown',
                      title: 'Partidas que diriges',
                      trailing: TextButton.icon(
                        onPressed: () => _demo(context, ref),
                        icon: const GameIcon('sparkles', size: 18),
                        label: const Text('Partida de ejemplo'),
                      ),
                    ),
                    hosted.when(
                      data: (list) => list.isEmpty
                          ? const _Hint('Todavía no diriges ninguna partida.')
                          : Column(children: [for (final c in list) _HostedTile(campaign: c)]),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => _Hint('Error al leer las partidas: $e'),
                    ),
                    Gap.l,
                    const _Header(icon: 'party', title: 'Partidas en las que juegas'),
                    joined.when(
                      data: (list) => list.isEmpty
                          ? const _Hint('Cuando te unas a una partida aparecerá aquí, también sin conexión.')
                          : Column(children: [for (final j in list) _JoinedTile(joined: j)]),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => _Hint('Error: $e'),
                    ),
                    Gap.l,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final campaign = await Navigator.push<Campaign>(
      context,
      MaterialPageRoute(builder: (_) => const CreateCampaignScreen()),
    );
    ref.invalidate(hostedCampaignsProvider);
    if (campaign != null && context.mounted) await openHosted(context, ref, campaign);
  }

  Future<void> _demo(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    final ok = await confirm(
      context,
      'Partida de ejemplo',
      'Se creará «La Cripta del Rey Ceniza» con tres personajes ficticios, recetas, un combate en curso y notas, '
          'para que pruebes todo como máster. Puedes borrarla cuando quieras.',
      ok: 'Crear',
    );
    if (!ok || !context.mounted) return;
    final demo = buildDemoCampaign(dmUserId: profile.userId, dmName: profile.displayName);
    await ref.read(storageProvider).saveHosted(demo);
    ref.invalidate(hostedCampaignsProvider);
    if (context.mounted) await openHosted(context, ref, demo);
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const JoinScreen()));
    ref.invalidate(joinedCampaignsProvider);
  }
}

/// Abre una partida como máster: arranca el servidor y entra en la partida.
Future<void> openHosted(BuildContext context, WidgetRef ref, Campaign campaign) async {
  final storage = ref.read(storageProvider);
  final fresh = await storage.loadHosted(campaign.id) ?? campaign;
  final session = HostSession(campaign: fresh, profile: ref.read(profileProvider), storage: storage);
  await session.start();
  if (!context.mounted) {
    await session.close();
    return;
  }
  await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => CampaignShell(session: session)));
  ref.invalidate(hostedCampaignsProvider);
}

/// Abre una partida como jugador (con la última copia guardada mientras conecta).
Future<void> openJoined(BuildContext context, WidgetRef ref, JoinedCampaign joined) async {
  final session = ClientSession(
    invite: joined.invite,
    profile: ref.read(profileProvider),
    storage: ref.read(storageProvider),
    cachedView: joined.lastView,
    cachedChat: joined.chat,
  )..start();
  await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => CampaignShell(session: session)));
  ref.invalidate(joinedCampaignsProvider);
}

class _Header extends StatelessWidget {
  const _Header({required this.icon, required this.title, this.trailing});
  final String icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        GameIcon(icon, size: 22),
        Gap.s,
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        ?trailing,
      ],
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.18), Colors.transparent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              GameIcon(icon, size: 52, color: color),
              Gap.m,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleLarge?.copyWith(color: color)),
                    Text(subtitle, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

String _ago(int ms) {
  if (ms <= 0) return 'nunca';
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'ahora';
  if (d.inHours < 1) return 'hace ${d.inMinutes} min';
  if (d.inDays < 1) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} d';
}

class _HostedTile extends ConsumerWidget {
  const _HostedTile({required this.campaign});
  final Campaign campaign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = campaign.members.where((m) => !m.banned).length;
    return Card(
      child: ListTile(
        leading: const GameIcon('castle', size: 34),
        title: Text(campaign.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('$players jugadores · ${campaign.characters.length} personajes · ${_ago(campaign.updatedAt)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pill(campaign.ruleset.short),
            PopupMenuButton<String>(
              onSelected: (v) async {
                final storage = ref.read(storageProvider);
                if (v == 'export') {
                  final path = await storage.exportCampaign(campaign);
                  if (context.mounted) showSnack(context, 'Copia guardada en $path');
                } else if (v == 'delete') {
                  final ok = await confirm(
                    context,
                    'Borrar partida',
                    'Se borrará "${campaign.name}" de este dispositivo con todos sus personajes. No se puede deshacer.',
                    ok: 'Borrar',
                    danger: true,
                  );
                  if (!ok) return;
                  await storage.deleteHosted(campaign.id);
                  ref.invalidate(hostedCampaignsProvider);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'export', child: Text('Exportar copia de seguridad')),
                PopupMenuItem(value: 'delete', child: Text('Borrar')),
              ],
            ),
          ],
        ),
        onTap: () => openHosted(context, ref, campaign),
      ),
    );
  }
}

class _JoinedTile extends ConsumerWidget {
  const _JoinedTile({required this.joined});
  final JoinedCampaign joined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = joined.lastView;
    final profile = ref.watch(profileProvider);
    final mine = view?.charactersOf(profile.userId) ?? const [];
    return Card(
      child: ListTile(
        leading: GameIcon(mine.isEmpty ? 'hood' : mine.first.portrait, size: 34),
        title: Text(joined.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          [
            if (mine.isNotEmpty) mine.map((c) => c.name).join(', '),
            'Máster: ${view?.dmName ?? joined.invite.dmName}',
            'conectado ${_ago(joined.lastConnectedAt)}',
          ].where((s) => s.isNotEmpty).join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (view != null) Pill(view.ruleset.short, color: AppColors.arcane),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'delete') {
                  final ok = await confirm(
                    context,
                    'Olvidar partida',
                    'Se borrará la copia local de "${joined.name}". Tu personaje sigue guardado en el dispositivo '
                        'del máster y podrás volver a unirte.',
                    ok: 'Olvidar',
                    danger: true,
                  );
                  if (!ok) return;
                  await ref.read(storageProvider).deleteJoined(joined.campaignId);
                  ref.invalidate(joinedCampaignsProvider);
                }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Olvidar esta partida'))],
            ),
          ],
        ),
        onTap: () => openJoined(context, ref, joined),
      ),
    );
  }
}
