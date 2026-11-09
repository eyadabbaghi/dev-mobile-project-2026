import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../models/community_report.dart';
import 'community_dialogs.dart';

/// Feuille de signalement réutilisable pour les publications et commentaires.
Future<bool> showReportSheet(
  BuildContext context, {
  required CommunityRepository repository,
  required String reporterId,
  String? reporterName,
  required ReportTargetType targetType,
  required String targetId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReportSheet(
      repository: repository,
      reporterId: reporterId,
      reporterName: reporterName,
      targetType: targetType,
      targetId: targetId,
    ),
  );
  return result == true;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.repository,
    required this.reporterId,
    required this.reporterName,
    required this.targetType,
    required this.targetId,
  });

  final CommunityRepository repository;
  final String reporterId;
  final String? reporterName;
  final ReportTargetType targetType;
  final String targetId;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final TextEditingController _details = TextEditingController();
  ReportReason _reason = ReportReason.spam;
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.repository.reportContent(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reporterId: widget.reporterId,
        reporterName: widget.reporterName,
        reason: _reason,
        details: _details.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Signaler ${widget.targetType == ReportTargetType.post ? 'la publication' : 'le commentaire'}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choisis un motif. Le signalement reste interne au module et '
              'sera examiné par le propriétaire du contenu.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final reason in ReportReason.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  _reason == reason
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: _reason == reason ? colors.primary : null,
                ),
                title: Text(reason.label),
                onTap: () => setState(() => _reason = reason),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Détails (optionnel)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.flag_rounded),
                label: Text(_sending ? 'Envoi…' : 'Envoyer le signalement'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
