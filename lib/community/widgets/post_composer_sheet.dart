import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/community_ai_service.dart';
import '../data/community_repository.dart';
import '../models/comment_insights.dart';
import '../models/community_profile.dart';
import '../models/poll.dart';
import '../models/post.dart';
import '../utils/community_formatters.dart';
import 'community_dialogs.dart';

/// Contenu renvoyé par le formulaire de création / modification (PUB01 / PUB03).
class PostDraft {
  const PostDraft({
    required this.content,
    required this.theme,
    this.imageBytes,
    this.videoBytes,
    this.videoName,
    this.isDraft = false,
    this.allowAnonymousComments = false,
    this.pollQuestion,
    this.pollOptions = const [],
    this.pollEndsAt,
    this.clearImage = false,
    this.clearVideo = false,
  });

  final String content;
  final PostTheme theme;
  final Uint8List? imageBytes;
  final Uint8List? videoBytes;
  final String? videoName;
  final bool isDraft;
  final bool allowAnonymousComments;
  final String? pollQuestion;
  final List<String> pollOptions;
  final DateTime? pollEndsAt;
  final bool clearImage;
  final bool clearVideo;
}

class PostComposerSheet extends StatefulWidget {
  const PostComposerSheet({
    super.key,
    this.isEditing = false,
    this.initialContent = '',
    this.initialTheme = PostTheme.meal,
    this.initialImageBytes,
    this.initialVideoBytes,
    this.initialVideoName,
    this.initialAllowAnonymousComments = false,
    this.initialIsDraft = false,
    this.initialPoll,
    this.repository,
    this.currentUserId = '',
    this.aiService,
  });

  final bool isEditing;
  final String initialContent;
  final PostTheme initialTheme;
  final Uint8List? initialImageBytes;
  final Uint8List? initialVideoBytes;
  final String? initialVideoName;
  final bool initialAllowAnonymousComments;
  final bool initialIsDraft;
  final PostPoll? initialPoll;
  final CommunityRepository? repository;
  final String currentUserId;
  final CommunityAiService? aiService;

  @override
  State<PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends State<PostComposerSheet> {
  late final TextEditingController _controller;
  late final CommunityAiService _ai;
  late PostTheme _theme;
  late bool _allowAnonymousComments;
  late bool _keepAsDraft;

  Uint8List? _imageBytes;
  Uint8List? _videoBytes;
  String? _videoName;
  bool _pickingImage = false;
  bool _pickingVideo = false;
  bool _aiBusy = false;
  String _tone = 'amical';

  bool _pollEnabled = false;
  final TextEditingController _pollQuestion = TextEditingController();
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];
  DateTime? _pollEndsAt;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _ai = widget.aiService ?? CommunityAiService();
    _theme = widget.initialTheme;
    _allowAnonymousComments = widget.initialAllowAnonymousComments;
    _keepAsDraft = widget.initialIsDraft;
    _imageBytes = widget.initialImageBytes;
    _videoBytes = widget.initialVideoBytes;
    _videoName = widget.initialVideoName;
    _pollEnabled = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    _pollQuestion.dispose();
    for (final option in _pollOptions) {
      option.dispose();
    }
    if (widget.aiService == null) _ai.close();
    super.dispose();
  }

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  bool get _pollHasContent {
    if (!_pollEnabled) return false;
    final options = _pollOptions
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    return _pollQuestion.text.trim().isNotEmpty && options.length >= 2;
  }

  List<String> get _pollOptionValues => _pollOptions
      .map((controller) => controller.text.trim())
      .where((text) => text.isNotEmpty)
      .toList();

  Future<void> _pickMedia({required bool video}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                video ? 'Choisir une vidéo' : 'Galerie de photos',
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(
                video ? Icons.videocam_outlined : Icons.photo_camera_outlined,
              ),
              title: Text(
                video ? 'Filmer une vidéo' : 'Prendre une photo',
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    if (video) {
      await _pickVideo(source);
    } else {
      await _pickImage(source);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _pickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(
        context,
        'Impossible de sélectionner la photo : $error',
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    setState(() => _pickingVideo = true);
    try {
      final picked = await ImagePicker().pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _videoBytes = bytes;
        _videoName = picked.name;
      });
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(
        context,
        'Impossible de sélectionner la vidéo : $error',
      );
    } finally {
      if (mounted) setState(() => _pickingVideo = false);
    }
  }

  Future<void> _runAi(String action) async {
    if (_aiBusy) return;
    final currentText = _controller.text.trim();
    if (currentText.isEmpty && action != 'generate') {
      showCommunitySnack(
        context,
        'Écris d’abord un texte à améliorer ou corrige-le manuellement.',
      );
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final result = await _ai.generatePublication(
        prompt: currentText,
        action: action,
        tone: _tone,
        currentText: currentText,
        theme: _theme.label,
      );
      if (!mounted) return;
      await _showAiResult(result, action);
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _showAiResult(AiTextResult result, String action) async {
    final useResult = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Assistant IA')),
            AiSourceBadge(source: result.source, compact: true),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                action == 'hashtags'
                    ? 'Hashtags suggérés'
                    : 'Proposition de texte',
                style: Theme.of(dialogContext).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SelectableText(
                action == 'hashtags'
                    ? result.hashtags.join(' ')
                    : result.text,
                style: const TextStyle(height: 1.4),
              ),
              if (result.note != null) ...[
                const SizedBox(height: 10),
                Text(
                  result.note!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(
                      dialogContext,
                    ).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Rien n’est publié automatiquement : tu choisis d’utiliser ou non '
                'cette proposition.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    dialogContext,
                  ).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ignorer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Utiliser'),
          ),
        ],
      ),
    );
    if (useResult != true || !mounted) return;

    if (action == 'hashtags') {
      final tags = result.hashtags
          .map((tag) => tag.startsWith('#') ? tag : '#$tag')
          .where((tag) => tag.length > 1)
          .toList();
      if (tags.isNotEmpty) {
        final base = _controller.text.trimRight();
        _controller.text = base.isEmpty
            ? tags.join(' ')
            : '$base ${tags.join(' ')}';
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    } else if (result.text.trim().isNotEmpty) {
      _controller.text = result.text.trim();
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
    setState(() {});
  }

  Future<void> _insertMention() async {
    final repository = widget.repository;
    if (repository == null || widget.currentUserId.isEmpty) {
      showCommunitySnack(
        context,
        'Les mentions ne sont pas disponibles dans ce contexte.',
      );
      return;
    }
    List<CommunityProfile> profiles;
    try {
      profiles = await repository.getMentionableUsers(
        currentUserId: widget.currentUserId,
      );
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
      return;
    }
    if (!mounted) return;
    if (profiles.isEmpty) {
      showCommunitySnack(context, 'Aucun membre à mentionner pour le moment.');
      return;
    }
    final selected = await showDialog<CommunityProfile>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Mentionner un membre'),
        children: [
          for (final profile in profiles)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, profile),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    child: Text(
                      initialsOf(profile.displayName),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${profile.displayName}  @${profile.username}',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final mention = '@${selected.username} ';
    final selection = _controller.selection;
    final offset = selection.isValid
        ? selection.baseOffset
        : _controller.text.length;
    final text = _controller.text;
    _controller.text = text.replaceRange(offset, offset, mention);
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: offset + mention.length),
    );
    setState(() {});
  }

  Future<void> _pickPollEnd() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _pollEndsAt ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      helpText: 'Fin du sondage',
    );
    if (date == null) return;
    setState(() {
      _pollEndsAt = DateTime(date.year, date.month, date.day, 23, 59);
    });
  }

  void _submit({required bool asDraft}) {
    if (!_canSubmit) return;
    if (_pollEnabled && !_pollHasContent && !asDraft) {
      showCommunitySnack(
        context,
        'Complète la question et au moins deux options du sondage.',
      );
      return;
    }
    Navigator.pop(
      context,
      PostDraft(
        content: _controller.text.trim(),
        theme: _theme,
        imageBytes: _imageBytes,
        videoBytes: _videoBytes,
        videoName: _videoName,
        isDraft: asDraft,
        allowAnonymousComments: _allowAnonymousComments,
        pollQuestion: _pollEnabled ? _pollQuestion.text.trim() : null,
        pollOptions: _pollEnabled ? _pollOptionValues : const [],
        pollEndsAt: _pollEnabled ? _pollEndsAt : null,
        clearImage:
            widget.isEditing &&
            widget.initialImageBytes != null &&
            _imageBytes == null,
        clearVideo:
            widget.isEditing &&
            widget.initialVideoBytes != null &&
            _videoBytes == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isEditing
                        ? 'Modifier la publication'
                        : 'Nouvelle publication',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
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
              widget.isEditing
                  ? 'Mets à jour ton texte ou change le thème.'
                  : 'Partage une astuce, un repas ou une réussite.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            _buildAiBar(context),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: widget.isEditing,
              minLines: 4,
              maxLines: 10,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Quoi de neuf aujourd’hui ?',
                alignLabelWithHint: true,
                suffixIcon: IconButton(
                  tooltip: 'Mentionner un membre',
                  onPressed: _insertMention,
                  icon: const Icon(Icons.alternate_email_rounded),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _toneChip('amical', 'Amical'),
                _toneChip('professionnel', 'Professionnel'),
                _toneChip('motivant', 'Motivant'),
                _toneChip('humour', 'Humour'),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Thème',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in PostTheme.values)
                  ChoiceChip(
                    avatar: Icon(
                      option.icon,
                      size: 16,
                      color: _theme == option
                          ? colors.onPrimary
                          : option.color,
                    ),
                    label: Text(option.label),
                    selected: _theme == option,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _theme == option
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                    ),
                    backgroundColor: colors.surfaceContainerHighest,
                    selectedColor: colors.primary,
                    onSelected: (_) => setState(() => _theme = option),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_imageBytes == null)
              OutlinedButton.icon(
                onPressed: _pickingImage
                    ? null
                    : () => _pickMedia(video: false),
                icon: _pickingImage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _pickingImage ? 'Chargement…' : 'Ajouter une photo',
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Image.memory(
                      _imageBytes!,
                      width: double.infinity,
                      height: 190,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        tooltip: 'Retirer la photo',
                        onPressed: () => setState(() => _imageBytes = null),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (_videoBytes == null)
              OutlinedButton.icon(
                onPressed: _pickingVideo
                    ? null
                    : () => _pickMedia(video: true),
                icon: _pickingVideo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_library_outlined),
                label: Text(
                  _pickingVideo ? 'Chargement…' : 'Ajouter une vidéo',
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.videocam_rounded, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _videoName ?? 'Vidéo sélectionnée',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Retirer la vidéo',
                      onPressed: () => setState(() {
                        _videoBytes = null;
                        _videoName = null;
                      }),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (!widget.isEditing)
              _buildPollEditor(context)
            else if (widget.initialPoll != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.poll_outlined, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sondage : ${widget.initialPoll!.question} '
                        '(le sondage existant est conservé)',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 2),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _allowAnonymousComments,
              onChanged: (value) =>
                  setState(() => _allowAnonymousComments = value),
              title: const Text('Autoriser les commentaires anonymes'),
              subtitle: const Text(
                'Les membres pourront commenter sans afficher leur nom.',
              ),
            ),
            if (widget.isEditing)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _keepAsDraft,
                onChanged: (value) => setState(() => _keepAsDraft = value),
                title: const Text('Conserver comme brouillon'),
                subtitle: const Text(
                  'Le brouillon reste visible uniquement par toi.',
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!widget.isEditing)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _canSubmit
                          ? () => _submit(asDraft: true)
                          : null,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Brouillon'),
                    ),
                  ),
                if (!widget.isEditing) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _canSubmit
                        ? () => _submit(
                            asDraft: widget.isEditing && _keepAsDraft,
                          )
                        : null,
                    icon: Icon(
                      widget.isEditing
                          ? Icons.check_rounded
                          : Icons.send_rounded,
                    ),
                    label: Text(
                      widget.isEditing
                          ? 'Enregistrer'
                          : _keepAsDraft
                          ? 'Enregistrer le brouillon'
                          : 'Publier',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toneChip(String value, String label) {
    final colors = Theme.of(context).colorScheme;
    final selected = _tone == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: selected ? colors.onPrimary : colors.onSurfaceVariant,
      ),
      backgroundColor: colors.surfaceContainerHighest,
      selectedColor: colors.primary,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _tone = value),
    );
  }

  Widget _buildAiBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'Assistant IA',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_aiBusy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _aiAction('Générer', 'generate'),
              _aiAction('Améliorer', 'rewrite'),
              _aiAction('Corriger', 'correct'),
              _aiAction('Hashtags', 'hashtags'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aiAction(String label, String action) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.auto_fix_high_rounded, size: 14),
      onPressed: _aiBusy ? null : () => _runAi(action),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildPollEditor(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _pollEnabled,
              onChanged: (value) => setState(() => _pollEnabled = value),
              title: const Text('Ajouter un sondage'),
              subtitle: const Text('Pose une question à la communauté.'),
            ),
          ),
          if (_pollEnabled) ...[
            TextField(
              controller: _pollQuestion,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Question',
                counterText: '',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _pollOptions.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pollOptions[index],
                        maxLength: 60,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Option ${index + 1}',
                          counterText: '',
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_pollOptions.length > 2)
                      IconButton(
                        tooltip: 'Retirer l’option',
                        onPressed: () => setState(
                          () => _pollOptions.removeAt(index).dispose(),
                        ),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pollOptions.length >= 4
                      ? null
                      : () => setState(
                          () => _pollOptions.add(TextEditingController()),
                        ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Option'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickPollEnd,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                    _pollEndsAt == null
                        ? 'Date de fin'
                        : 'Fin ${_pollEndsAt!.day}/${_pollEndsAt!.month}',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
