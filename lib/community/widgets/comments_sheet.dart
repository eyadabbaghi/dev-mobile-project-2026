import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../data/community_ai_service.dart';
import '../data/community_repository.dart';
import '../models/comment_insights.dart';
import '../models/community_profile.dart';
import '../models/community_report.dart';
import '../models/post.dart';
import '../models/post_comment.dart';
import '../utils/community_formatters.dart';
import 'community_dialogs.dart';
import 'reaction_picker.dart';
import 'report_sheet.dart';

enum _CommentSort { pinned, newest, oldest, mostLiked }

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    required this.post,
    required this.currentUser,
    required this.repository,
    this.aiService,
  });

  final Post post;
  final User currentUser;
  final CommunityRepository repository;
  final CommunityAiService? aiService;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final CommunityAiService _ai;

  List<PostComment> _comments = [];
  bool _loading = true;
  bool _sending = false;
  bool _changed = false;
  bool _anonymous = false;
  bool _aiBusy = false;
  String? _replyingToId;
  String _replyingToName = '';
  _CommentSort _sort = _CommentSort.pinned;

  @override
  void initState() {
    super.initState();
    _ai = widget.aiService ?? CommunityAiService();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    if (widget.aiService == null) _ai.close();
    super.dispose();
  }

  String get _authorName =>
      '${widget.currentUser.firstName} ${widget.currentUser.lastName}';

  bool get _ownsPost => widget.post.isOwnedBy(widget.currentUser.id);

  Future<void> _loadComments() async {
    try {
      final comments = await widget.repository.getComments(
        widget.post.id,
        currentUserId: widget.currentUser.id,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(error);
    }
  }

  List<PostComment> get _rootComments {
    final roots = _comments
        .where((comment) => comment.parentId == null)
        .toList();
    switch (_sort) {
      case _CommentSort.pinned:
        roots.sort((a, b) {
          final pin = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
          if (pin != 0) return pin;
          final best = (b.isBestAnswer ? 1 : 0).compareTo(
            a.isBestAnswer ? 1 : 0,
          );
          if (best != 0) return best;
          return a.createdAt.compareTo(b.createdAt);
        });
      case _CommentSort.newest:
        roots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _CommentSort.oldest:
        roots.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _CommentSort.mostLiked:
        roots.sort((a, b) => b.reactionCount.compareTo(a.reactionCount));
    }
    return roots;
  }

  List<PostComment> _repliesOf(String commentId) {
    final replies = _comments
        .where((comment) => comment.parentId == commentId)
        .toList();
    replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return replies;
  }

  Future<void> _addComment() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final moderation = await _ai.moderateText(content);
      final spam = await _ai.detectSpam(
        text: content,
        recentComments: _comments
            .take(12)
            .map((comment) => comment.content)
            .toList(),
      );
      final sentiment = await _ai.analyzeSentiment(content);
      if (!mounted) return;

      if (moderation.isFlagged || spam.isSpam) {
        final confirmed = await _confirmFlagged(
          moderation: moderation,
          spam: spam,
        );
        if (confirmed != true) {
          setState(() => _sending = false);
          return;
        }
      }

      final created = await widget.repository.addComment(
        postId: widget.post.id,
        userId: widget.currentUser.id,
        authorName: _authorName,
        authorAvatarPath: widget.currentUser.profilePicturePath,
        content: content,
        parentId: _replyingToId,
        isAnonymous: _anonymous,
        sentiment: sentiment.sentiment,
        isFlagged: moderation.isFlagged,
        flagReason: moderation.isFlagged ? moderation.summary : null,
        isSpam: spam.isSpam,
        spamReason: spam.isSpam ? spam.reason : null,
      );
      if (moderation.isFlagged || spam.isSpam) {
        await _saveFlag(created, moderation: moderation, spam: spam);
      }
      _controller.clear();
      _replyingToId = null;
      _replyingToName = '';
      _changed = true;
      await _loadComments();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveFlag(
    PostComment comment, {
    required AiModerationResult moderation,
    required AiSpamResult spam,
  }) async {
    try {
      await widget.repository.saveContentFlag(
        targetType: ReportTargetType.comment,
        targetId: comment.id,
        ownerId: comment.userId,
        postOwnerId: widget.post.userId,
        category: spam.isSpam
            ? 'Spam'
            : moderation.categories.isNotEmpty
            ? moderation.categories.first
            : 'Contenu sensible',
        explanation: spam.isSpam ? spam.reason : moderation.summary,
        source: spam.isSpam ? spam.source : moderation.source,
      );
    } catch (_) {
      // L'alerte est un info-bulle de modération : elle ne bloque pas
      // l'enregistrement du commentaire.
    }
  }

  Future<bool?> _confirmFlagged({
    required AiModerationResult moderation,
    required AiSpamResult spam,
  }) {
    final source = spam.isSpam ? spam.source : moderation.source;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            const Expanded(child: Text('Alerte de modération')),
            AiSourceBadge(source: source, compact: true),
          ],
        ),
        content: Text(
          moderation.isFlagged
              ? '${moderation.summary}\n\n'
                    'Ce commentaire n’a pas été publié automatiquement : '
                    'tu choisis de l’envoyer ou non.'
              : 'Ce commentaire ressemble à du spam : ${spam.reason}\n\n'
                    'Tu restes libre de le publier.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Publier quand même'),
          ),
        ],
      ),
    );
  }

  Future<void> _react(PostComment comment) async {
    final selection = await showReactionPicker(
      context,
      current: comment.myReaction,
    );
    if (selection == null || selection.reaction == null) return;
    try {
      await widget.repository.toggleCommentReaction(
        commentId: comment.id,
        userId: widget.currentUser.id,
        reaction: selection.reaction!,
        actorName: _authorName,
      );
      _changed = true;
      await _loadComments();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _editComment(PostComment comment) async {
    final controller = TextEditingController(text: comment.content);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier le commentaire'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          maxLength: 400,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ton commentaire'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null || result.trim().isEmpty) return;
    try {
      final sentiment = await _ai.analyzeSentiment(result);
      await widget.repository.updateComment(
        commentId: comment.id,
        userId: widget.currentUser.id,
        content: result,
        sentiment: sentiment.sentiment,
      );
      _changed = true;
      await _loadComments();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteComment(PostComment comment) async {
    final confirmed = await showCommunityConfirmDialog(
      context,
      title: 'Supprimer le commentaire ?',
      message: 'Cette action est définitive.',
    );
    if (!confirmed) return;

    try {
      await widget.repository.deleteComment(
        commentId: comment.id,
        userId: widget.currentUser.id,
      );
      _changed = true;
      await _loadComments();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _togglePin(PostComment comment) async {
    try {
      await widget.repository.togglePinComment(
        commentId: comment.id,
        postId: widget.post.id,
        userId: widget.currentUser.id,
      );
      _changed = true;
      await _loadComments();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleBestAnswer(PostComment comment) async {
    try {
      await widget.repository.toggleBestAnswer(
        commentId: comment.id,
        postId: widget.post.id,
        userId: widget.currentUser.id,
      );
      _changed = true;
      await _loadComments();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reportComment(PostComment comment) async {
    final reported = await showReportSheet(
      context,
      repository: widget.repository,
      reporterId: widget.currentUser.id,
      reporterName: _authorName,
      targetType: ReportTargetType.comment,
      targetId: comment.id,
    );
    if (reported && mounted) {
      showCommunitySnack(context, 'Signalement envoyé au propriétaire.');
    }
  }

  Future<void> _translate(PostComment comment) async {
    final language = await showDialog<CommunityLanguage>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Traduire le commentaire'),
        children: [
          for (final language in CommunityLanguage.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, language),
              child: Text(language.label),
            ),
        ],
      ),
    );
    if (language == null || !mounted) return;

    setState(() => _aiBusy = true);
    try {
      final result = await _ai.translate(
        text: comment.content,
        target: language,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text('Traduction · ${language.label}')),
              AiSourceBadge(source: result.source, compact: true),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(result.text),
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
              const SizedBox(height: 10),
              Text(
                'Le commentaire original reste inchangé.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    dialogContext,
                  ).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _suggestReplies(PostComment comment) async {
    setState(() => _aiBusy = true);
    try {
      final suggestions = await _ai.suggestReplies(
        postContent: widget.post.content,
        commentContent: comment.content,
      );
      if (!mounted) return;
      final selected = await showModalBottomSheet<AiReplySuggestion>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggestions de réponse',
                  style: Theme.of(sheetContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choisis une proposition : elle sera ajoutée au champ, sans '
                  'être publiée automatiquement.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final suggestion in suggestions)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(suggestion.text),
                      subtitle: Text(suggestion.tone),
                      onTap: () =>
                          Navigator.pop(sheetContext, suggestion),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      if (selected == null || !mounted) return;
      _replyingToId = comment.id;
      _replyingToName = comment.displayAuthorName;
      _controller.text = selected.text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      _focusNode.requestFocus();
      setState(() {});
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _summarizeDiscussion() async {
    if (_comments.isEmpty) {
      showCommunitySnack(context, 'Aucun commentaire à résumer.');
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final summary = await _ai.summarizeDiscussion(
        postContent: widget.post.content,
        comments: _comments,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text('Résumé de la discussion')),
              AiSourceBadge(source: summary.source, compact: true),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.summary, style: const TextStyle(height: 1.4)),
                if (summary.mainOpinions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Opinions principales', style: TextStyle(fontWeight: FontWeight.w700)),
                  for (final opinion in summary.mainOpinions)
                    Text('• $opinion'),
                ],
                if (summary.frequentlyAskedQuestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Questions fréquentes', style: TextStyle(fontWeight: FontWeight.w700)),
                  for (final question in summary.frequentlyAskedQuestions)
                    Text('• $question'),
                ],
                if (summary.highlights.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Points forts', style: TextStyle(fontWeight: FontWeight.w700)),
                  for (final highlight in summary.highlights)
                    Text('• $highlight'),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _showInsights() async {
    final counts = <CommentSentiment, int>{};
    for (final comment in _comments) {
      final sentiment = comment.sentiment;
      if (sentiment != null) {
        counts[sentiment] = (counts[sentiment] ?? 0) + 1;
      }
    }
    final flagged = _comments.where((comment) => comment.isFlagged).length;
    final spam = _comments.where((comment) => comment.isSpam).length;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analyse de la discussion',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (counts.isEmpty)
                const Text('Aucun sentiment détecté pour le moment.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in counts.entries)
                      Chip(
                        avatar: Icon(
                          entry.key.icon,
                          size: 16,
                          color: entry.key.color,
                        ),
                        label: Text('${entry.key.label} · ${entry.value}'),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    avatar: const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Colors.orangeAccent,
                    ),
                    label: Text('Alertes IA · $flagged'),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const Icon(
                      Icons.report_gmailerrorred_rounded,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    label: Text('Spam · $spam'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _insertMention() async {
    List<CommunityProfile> profiles;
    try {
      profiles = await widget.repository.getMentionableUsers(
        currentUserId: widget.currentUser.id,
      );
    } catch (error) {
      _showError(error);
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
              child: Text('${profile.displayName}  @${profile.username}'),
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
    _controller.text = _controller.text.replaceRange(offset, offset, mention);
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: offset + mention.length),
    );
    setState(() {});
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is CommunityException
        ? error.message
        : communityErrorMessage(error);
    showCommunitySnack(context, message);
  }

  void _close() => Navigator.pop(context, _changed);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commentaires',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          '${_comments.length} commentaire${_comments.length == 1 ? '' : 's'}'
                          '${widget.post.allowAnonymousComments ? ' · anonymat autorisé' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_CommentSort>(
                    tooltip: 'Trier les commentaires',
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    icon: const Icon(Icons.sort_rounded),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _CommentSort.pinned,
                        child: Text('Épinglés et meilleures réponses'),
                      ),
                      PopupMenuItem(
                        value: _CommentSort.newest,
                        child: Text('Plus récents'),
                      ),
                      PopupMenuItem(
                        value: _CommentSort.oldest,
                        child: Text('Plus anciens'),
                      ),
                      PopupMenuItem(
                        value: _CommentSort.mostLiked,
                        child: Text('Plus réagis'),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Outils IA',
                    enabled: !_aiBusy,
                    onSelected: (value) {
                      if (value == 'summary') {
                        _summarizeDiscussion();
                      } else {
                        _showInsights();
                      }
                    },
                    icon: _aiBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'summary',
                        child: Text('Résumer la discussion'),
                      ),
                      PopupMenuItem(
                        value: 'insights',
                        child: Text('Analyse des sentiments'),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: _close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildList(context)),
            _buildComposer(context),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final roots = _rootComments;
    if (roots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 38,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Aucun commentaire',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sois le premier à réagir à cette publication.',
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      itemCount: roots.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _threadTile(context, roots[index], 0),
    );
  }

  Widget _threadTile(BuildContext context, PostComment comment, int depth) {
    final replies = _repliesOf(comment.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _commentTile(context, comment),
        if (replies.isNotEmpty && depth < 4)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 8),
            child: Column(
              children: [
                for (final reply in replies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _threadTile(context, reply, depth + 1),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _commentTile(BuildContext context, PostComment comment) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isOwn = comment.isOwnedBy(widget.currentUser.id);
    final isAnonymous = comment.isAnonymous;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: isAnonymous
              ? colors.tertiaryContainer
              : colors.primaryContainer,
          foregroundColor: isAnonymous
              ? colors.onTertiaryContainer
              : colors.onPrimaryContainer,
          child: isAnonymous
              ? const Icon(Icons.visibility_off_outlined, size: 16)
              : Text(
                  initialsOf(comment.authorName),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              color: comment.isBestAnswer
                  ? colors.primary.withValues(alpha: 0.11)
                  : colors.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: comment.isPinned
                  ? Border.all(color: colors.primary.withValues(alpha: 0.5))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.displayAuthorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (comment.sentiment != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Tooltip(
                          message: 'Sentiment : ${comment.sentiment!.label}',
                          child: Icon(
                            comment.sentiment!.icon,
                            size: 15,
                            color: comment.sentiment!.color,
                          ),
                        ),
                      ),
                    Text(
                      formatPostTime(comment.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Gérer le commentaire',
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      onSelected: (value) {
                        switch (value) {
                          case 'reply':
                            _startReply(comment);
                          case 'ai':
                            _suggestReplies(comment);
                          case 'translate':
                            _translate(comment);
                          case 'edit':
                            _editComment(comment);
                          case 'delete':
                            _deleteComment(comment);
                          case 'report':
                            _reportComment(comment);
                          case 'pin':
                            _togglePin(comment);
                          case 'best':
                            _toggleBestAnswer(comment);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'reply',
                          child: _MenuRow(
                            icon: Icons.reply_rounded,
                            label: 'Répondre',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'ai',
                          child: _MenuRow(
                            icon: Icons.auto_awesome_rounded,
                            label: 'Suggestions IA',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'translate',
                          child: _MenuRow(
                            icon: Icons.translate_rounded,
                            label: 'Traduire',
                          ),
                        ),
                        if (_ownsPost)
                          PopupMenuItem(
                            value: 'pin',
                            child: _MenuRow(
                              icon: comment.isPinned
                                  ? Icons.push_pin_outlined
                                  : Icons.push_pin_rounded,
                              label: comment.isPinned
                                  ? 'Désépingler'
                                  : 'Épingler',
                            ),
                          ),
                        if (_ownsPost)
                          PopupMenuItem(
                            value: 'best',
                            child: _MenuRow(
                              icon: Icons.workspace_premium_outlined,
                              label: comment.isBestAnswer
                                  ? 'Retirer la meilleure réponse'
                                  : 'Meilleure réponse',
                            ),
                          ),
                        if (isOwn)
                          const PopupMenuItem(
                            value: 'edit',
                            child: _MenuRow(
                              icon: Icons.edit_outlined,
                              label: 'Modifier',
                            ),
                          ),
                        if (isOwn)
                          const PopupMenuItem(
                            value: 'delete',
                            child: _MenuRow(
                              icon: Icons.delete_outline,
                              label: 'Supprimer',
                              color: Colors.redAccent,
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'report',
                          child: _MenuRow(
                            icon: Icons.flag_outlined,
                            label: 'Signaler',
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (comment.isPinned || comment.isBestAnswer)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 2),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        if (comment.isPinned)
                          _badge(
                            context,
                            Icons.push_pin_rounded,
                            'Épinglé',
                            colors.primary,
                          ),
                        if (comment.isBestAnswer)
                          _badge(
                            context,
                            Icons.workspace_premium_rounded,
                            'Meilleure réponse',
                            const Color(0xFF8BD17C),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    comment.content,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
                if (comment.hasAiWarning) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            comment.isSpam
                                ? 'Signalé comme spam · ${comment.spamReason ?? ''}'
                                : 'Alerte IA · ${comment.flagReason ?? ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (comment.isEdited) ...[
                  const SizedBox(height: 3),
                  Text(
                    'modifié',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _react(comment),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (comment.myReaction != null)
                              Text(
                                comment.myReaction!.emoji,
                                style: const TextStyle(fontSize: 15),
                              )
                            else
                              Icon(
                                Icons.add_reaction_outlined,
                                size: 16,
                                color: colors.onSurfaceVariant,
                              ),
                            if (comment.reactionCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${comment.reactionCount}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: comment.myReaction != null
                                      ? comment.myReaction!.color
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _startReply(comment),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Répondre'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _startReply(PostComment comment) {
    setState(() {
      _replyingToId = comment.id;
      _replyingToName = comment.displayAuthorName;
    });
    _focusNode.requestFocus();
  }

  Widget _badge(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingToId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.reply_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Réponse à $_replyingToName',
                        style: TextStyle(fontSize: 12, color: colors.primary),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _replyingToId = null;
                        _replyingToName = '';
                      }),
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 400,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: _replyingToId == null
                          ? 'Écrire un commentaire…'
                          : 'Répondre à $_replyingToName…',
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Mentionner un membre',
                        onPressed: _insertMention,
                        icon: const Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (widget.post.allowAnonymousComments)
                  IconButton(
                    tooltip: _anonymous
                        ? 'Commenter avec mon nom'
                        : 'Commenter anonymement',
                    onPressed: () => setState(() => _anonymous = !_anonymous),
                    icon: Icon(
                      _anonymous
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_outlined,
                      color: _anonymous ? colors.primary : null,
                    ),
                  ),
                IconButton.filled(
                  tooltip: 'Envoyer',
                  onPressed: (_sending || _controller.text.trim().isEmpty)
                      ? null
                      : _addComment,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
            if (_anonymous)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.visibility_off_rounded,
                      size: 13,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ton nom ne sera pas affiché.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}
