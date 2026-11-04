import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo.dart';
import '../../data/storage.dart';
import '../../domain/campaign.dart';
import '../../state/client_session.dart';
import '../../state/host_session.dart';
import '../../state/providers.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'campaign_shell.dart';
import 'create_campaign_screen.dart';
import 'join_screen.dart';
import 'profile_screen.dart';
import '../../core/i18n.dart';

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
            tr('DnD Tracker'),
            style: t.titleLarge?.copyWith(fontFamily: 'CinzelDecorative', color: AppColors.gold),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: tr('Perfil y ajustes'),
          icon: const Icon(Icons.person_outline),
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
        ),
        IconButton(
          tooltip: tr('Créditos y licencias'),
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
                    HeroBanner(
                      height: isDesktopLayout(context) ? 220 : 170,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'DnD Tracker',
                              style: TextStyle(
                                fontFamily: 'CinzelDecorative',
                                fontWeight: FontWeight.w700,
                                fontSize: isDesktopLayout(context) ? 38 : 28,
                                color: AppColors.gold,
                                shadows: const [Shadow(blurRadius: 12, color: Colors.black)],
                              ),
                            ),
                            Text(
                              tr('Saludos, {0}', [profile.displayName]),
                              style: t.headlineSmall?.copyWith(
                                shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                              ),
                            ),
                            Text(
                              tr('¿Diriges o juegas hoy?'),
                              style: t.bodyLarge?.copyWith(
                                color: AppColors.parchment.withValues(alpha: 0.85),
                                shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Gap.m,
                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth > 560;
                        final cards = [
                          _ActionCard(
                            icon: 'crowned_skull',
                            title: tr('Crear partida'),
                            subtitle: tr('Serás el máster y el anfitrión'),
                            color: AppColors.gold,
                            onTap: () => _create(context, ref),
                          ),
                          _ActionCard(
                            icon: 'rally',
                            title: tr('Unirse a partida'),
                            subtitle: tr('Con la invitación del máster'),
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
                      title: tr('Partidas que diriges'),
                      trailing: TextButton.icon(
                        onPressed: () => _demo(context, ref),
                        icon: const GameIcon('sparkles', size: 18),
                        label: Text(tr('Partida de ejemplo')),
                      ),
                    ),
                    hosted.when(
                      data: (list) => list.isEmpty
                          ? _Hint(tr('Todavía no diriges ninguna partida.'))
                          : Column(children: [for (final c in list) _HostedTile(campaign: c)]),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => _Hint(tr('Error al leer las partidas: {0}', [e])),
                    ),
                    Gap.l,
                    _Header(icon: 'party', title: tr('Partidas en las que juegas')),
                    joined.when(
                      data: (list) => list.isEmpty
                          ? _Hint(tr('Cuando te unas a una partida aparecerá aquí, también sin conexión.'))
                          : Column(children: [for (final j in list) _JoinedTile(joined: j)]),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => _Hint(tr('Error: {0}', [e])),
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
      tr('Partida de ejemplo'),
      tr(
        'Se creará «La Cripta del Rey Ceniza» con tres personajes ficticios, recetas, un combate en curso y notas, para que pruebes todo como máster. Puedes borrarla cuando quieras.',
      ),
      ok: tr('Crear'),
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
  if (ms <= 0) return tr('nunca');
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return tr('ahora');
  if (d.inHours < 1) return tr('hace {0} min', [d.inMinutes]);
  if (d.inDays < 1) return tr('hace {0} h', [d.inHours]);
  return tr('hace {0} d', [d.inDays]);
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
        subtitle: Text(
          tr('{0} jugadores · {1} personajes · {2}', [players, campaign.characters.length, _ago(campaign.updatedAt)]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pill(campaign.ruleset.short),
            PopupMenuButton<String>(
              onSelected: (v) async {
                final storage = ref.read(storageProvider);
                if (v == 'export') {
                  final path = await storage.exportCampaign(campaign);
                  if (context.mounted) showSnack(context, tr('Copia guardada en {0}', [path]));
                } else if (v == 'delete') {
                  final ok = await confirm(
                    context,
                    tr('Borrar partida'),
                    tr('Se borrará "{0}" de este dispositivo con todos sus personajes. No se puede deshacer.', [
                      campaign.name,
                    ]),
                    ok: tr('Borrar'),
                    danger: true,
                  );
                  if (!ok) return;
                  await storage.deleteHosted(campaign.id);
                  ref.invalidate(hostedCampaignsProvider);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'export', child: Text(tr('Exportar copia de seguridad'))),
                PopupMenuItem(value: 'delete', child: Text(tr('Borrar'))),
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
    final mine = view?.charactersOf(profile.userId) ?? [];
    return Card(
      child: ListTile(
        leading: GameIcon(mine.isEmpty ? 'hood' : mine.first.portrait, size: 34),
        title: Text(joined.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          [
            if (mine.isNotEmpty) mine.map((c) => c.name).join(', '),
            tr('Máster: {0}', [view?.dmName ?? joined.invite.dmName]),
            tr('conectado {0}', [_ago(joined.lastConnectedAt)]),
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
                    tr('Olvidar partida'),
                    tr(
                      'Se borrará la copia local de "{0}". Tu personaje sigue guardado en el dispositivo del máster y podrás volver a unirte.',
                      [joined.name],
                    ),
                    ok: tr('Olvidar'),
                    danger: true,
                  );
                  if (!ok) return;
                  await ref.read(storageProvider).deleteJoined(joined.campaignId);
                  ref.invalidate(joinedCampaignsProvider);
                }
              },
              itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(tr('Olvidar esta partida')))],
            ),
          ],
        ),
        onTap: () => openJoined(context, ref, joined),
      ),
    );
  }
}
