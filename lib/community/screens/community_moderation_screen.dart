import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../data/community_repository.dart';
import '../models/community_report.dart';
import '../utils/community_formatters.dart';
import '../widgets/community_dialogs.dart';

class CommunityModerationScreen extends StatefulWidget {
  const CommunityModerationScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final User user;
  final CommunityRepository repository;

  @override
  State<CommunityModerationScreen> createState() =>
      _CommunityModerationScreenState();
}

class _CommunityModerationScreenState extends State<CommunityModerationScreen> {
  List<ContentReport> _received = [];
  List<ContentReport> _mine = [];
  List<ContentFlag> _flags = [];
  List<ModerationAction> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.repository.getReportsOnMyContent(widget.user.id),
        widget.repository.getMyReports(widget.user.id),
        widget.repository.getFlagsForMyContent(widget.user.id),
        widget.repository.getModerationHistory(widget.user.id),
      ]);
      if (!mounted) return;
      setState(() {
        _received = results[0] as List<ContentReport>;
        _mine = results[1] as List<ContentReport>;
        _flags = results[2] as List<ContentFlag>;
        _history = results[3] as List<ModerationAction>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  Future<void> _resolve(ContentReport report, ReportStatus status) async {
    try {
      await widget.repository.resolveReport(
        reportId: report.id,
        userId: widget.user.id,
        status: status,
      );
      if (!mounted) return;
      showCommunitySnack(
        context,
        status == ReportStatus.reviewed
            ? 'Signalement marqué comme examiné.'
            : 'Signalement ignoré.',
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  Future<void> _dismissFlag(ContentFlag flag) async {
    try {
      await widget.repository.dismissFlag(
        flagId: flag.id,
        userId: widget.user.id,
      );
      if (!mounted) return;
      showCommunitySnack(context, 'Alerte IA ignorée.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Modération de mon contenu'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Reçus (${_received.length})'),
              Tab(text: 'Alertes IA (${_flags.length})'),
              Tab(text: 'Mes signalements (${_mine.length})'),
              const Tab(text: 'Historique'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _reportList(context, _received, received: true),
                  _flagList(context),
                  _reportList(context, _mine, received: false),
                  _historyList(context),
                ],
              ),
      ),
    );
  }

  Widget _empty(BuildContext context, IconData icon, String title, String body) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportList(
    BuildContext context,
    List<ContentReport> reports, {
    required bool received,
  }) {
    if (reports.isEmpty) {
      return _empty(
        context,
        Icons.shield_outlined,
        'Aucun signalement',
        received
            ? 'Les signalements concernant ton contenu apparaîtront ici.'
            : 'Tu n’as encore signalé aucune publication ni aucun commentaire.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final report = reports[index];
        return _ReportCard(
          report: report,
          received: received,
          onReviewed: received
              ? () => _resolve(report, ReportStatus.reviewed)
              : null,
          onDismissed: received
              ? () => _resolve(report, ReportStatus.dismissed)
              : null,
        );
      },
    );
  }

  Widget _flagList(BuildContext context) {
    if (_flags.isEmpty) {
      return _empty(
        context,
        Icons.auto_awesome_rounded,
        'Aucune alerte IA',
        'Les alertes de modération générées par l’IA apparaîtront ici.',
      );
    }
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _flags.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final flag = _flags[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      avatar: Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: Colors.orangeAccent,
                      ),
                      label: Text(flag.category),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    AiSourceBadge(source: flag.source, compact: true),
                    const Spacer(),
                    Text(
                      formatPostTime(flag.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (flag.targetPreview.isNotEmpty)
                  Text(
                    flag.targetPreview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                const SizedBox(height: 6),
                Text(
                  flag.explanation,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      flag.targetType.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (flag.status == ContentFlagStatus.pending)
                      TextButton.icon(
                        onPressed: () => _dismissFlag(flag),
                        icon: const Icon(Icons.visibility_off_outlined, size: 16),
                        label: const Text('Ignorer'),
                      )
                    else
                      Chip(
                        label: Text(flag.status.label),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _historyList(BuildContext context) {
    if (_history.isEmpty) {
      return _empty(
        context,
        Icons.history_rounded,
        'Aucun historique',
        'Les actions de modération sur ton contenu seront conservées ici.',
      );
    }
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final action = _history[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(action.action),
            subtitle: Text(
              formatPostTime(action.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: action.targetType == null
                ? null
                : Text(action.targetType!.label),
          ),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.received,
    this.onReviewed,
    this.onDismissed,
  });

  final ContentReport report;
  final bool received;
  final VoidCallback? onReviewed;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  avatar: Icon(
                    Icons.flag_outlined,
                    size: 14,
                    color: Colors.redAccent,
                  ),
                  label: Text(report.reason.label),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                Chip(
                  label: Text(report.targetType.label),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                _statusChip(context),
              ],
            ),
            const SizedBox(height: 8),
            if (report.targetPreview.isNotEmpty)
              Text(
                report.targetPreview,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            if (report.details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Détails : ${report.details}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  received
                      ? 'Signalé par ${report.reporterName ?? 'un membre'}'
                      : 'Signalé ${formatPostTime(report.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (received && report.status == ReportStatus.pending) ...[
                  TextButton(
                    onPressed: onDismissed,
                    child: const Text('Ignorer'),
                  ),
                  FilledButton(
                    onPressed: onReviewed,
                    child: const Text('Examiné'),
                  ),
                ],
              ],
            ),
            if (report.resolutionNote != null &&
                report.resolutionNote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Note : ${report.resolutionNote}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context) {
    final color = switch (report.status) {
      ReportStatus.pending => Colors.orangeAccent,
      ReportStatus.reviewed => const Color(0xFF8BD17C),
      ReportStatus.dismissed => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        report.status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
