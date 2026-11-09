import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user.dart';
import '../data/community_repository.dart';
import '../models/community_report.dart';
import '../models/community_reaction.dart';
import '../models/poll.dart';
import '../models/post.dart';
import '../utils/community_formatters.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/community_dialogs.dart';
import '../widgets/community_notifications_sheet.dart';
import '../widgets/post_card.dart';
import '../widgets/post_composer_sheet.dart';
import '../widgets/reaction_picker.dart';
import '../widgets/report_sheet.dart';
import 'community_bookmarks_screen.dart';
import 'community_drafts_screen.dart';
import 'community_moderation_screen.dart';

enum _FeedSort { newest, oldest, mostLiked, mostCommented, trending }

/// Module 5 : Publications & Commentaires.
class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key, required this.user, this.repository});

  final User user;

  /// Injectable pour les tests ; l'écran crée son dépôt par défaut.
  final CommunityRepository? repository;

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  late final CommunityRepository _repository;

  List<Post> _posts = [];
  PostTheme? _selectedTheme;
  String _searchQuery = '';
  final TextEditingController _searchDialogController = TextEditingController();
  _FeedSort _sort = _FeedSort.newest;
  bool _loading = true;
  String? _error;
  int _unreadNotifications = 0;

  String get _authorName =>
      '${widget.user.firstName} ${widget.user.lastName}';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CommunityRepository();
    _loadFeed();
    _refreshNotifications();
    _checkPollClosures();
  }

  Future<void> _loadFeed({bool showLoader = true}) async {
    if (showLoader) setState(() => _loading = true);
    try {
      final posts = await _repository.getFeed(
        currentUserId: widget.user.id,
        theme: _selectedTheme,
      );
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les publications.';
      });
    }
  }

  Future<void> _refreshNotifications() async {
    try {
      final count = await _repository.getUnreadNotificationCount(
        widget.user.id,
      );
      if (!mounted) return;
      setState(() => _unreadNotifications = count);
    } catch (_) {
      // Les notifications sont un complément : le fil reste utilisable.
    }
  }

  Future<void> _checkPollClosures() async {
    try {
      await _repository.checkPollClosures(widget.user.id);
    } catch (_) {
      // Fonctionnalité optionnelle, aucune erreur bloquante.
    }
  }

  Future<void> _createPost() async {
    final draft = await showModalBottomSheet<PostDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PostComposerSheet(
        repository: _repository,
        currentUserId: widget.user.id,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      await _repository.createPost(
        userId: widget.user.id,
        authorName: _authorName,
        authorAvatarPath: widget.user.profilePicturePath,
        content: draft.content,
        theme: draft.theme,
        imageBytes: draft.imageBytes,
        videoBytes: draft.videoBytes,
        videoName: draft.videoName,
        isDraft: draft.isDraft,
        allowAnonymousComments: draft.allowAnonymousComments,
        pollQuestion: draft.pollQuestion,
        pollOptions: draft.pollOptions,
        pollEndsAt: draft.pollEndsAt,
      );
      await _loadFeed(showLoader: false);
      if (!mounted) return;
      showCommunitySnack(
        context,
        draft.isDraft ? 'Brouillon enregistré.' : 'Publication partagée.',
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _editPost(Post post) async {
    final draft = await showModalBottomSheet<PostDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PostComposerSheet(
        isEditing: true,
        initialContent: post.content,
        initialTheme: post.theme,
        initialImageBytes: post.imageBytes,
        initialVideoBytes: post.videoBytes,
        initialVideoName: post.videoName,
        initialAllowAnonymousComments: post.allowAnonymousComments,
        initialIsDraft: post.isDraft,
        initialPoll: post.poll,
        repository: _repository,
        currentUserId: widget.user.id,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      await _repository.updatePost(
        postId: post.id,
        userId: widget.user.id,
        content: draft.content,
        theme: draft.theme,
        isDraft: draft.isDraft,
        allowAnonymousComments: draft.allowAnonymousComments,
        imageBytes: draft.imageBytes,
        clearImage: draft.clearImage,
        videoBytes: draft.videoBytes,
        videoName: draft.videoName,
        clearVideo: draft.clearVideo,
      );
      await _loadFeed(showLoader: false);
      if (!mounted) return;
      showCommunitySnack(context, 'Publication mise à jour.');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deletePost(Post post) async {
    final confirmed = await showCommunityConfirmDialog(
      context,
      title: 'Supprimer la publication ?',
      message:
          'Le texte, les médias et les commentaires associés seront '
          'définitivement supprimés.',
    );
    if (!confirmed) return;

    try {
      await _repository.deletePost(
        postId: post.id,
        userId: widget.user.id,
      );
      if (!mounted) return;
      setState(() => _posts.removeWhere((item) => item.id == post.id));
      showCommunitySnack(context, 'Publication supprimée.');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _togglePin(Post post) async {
    try {
      final pinned = await _repository.togglePinPost(
        postId: post.id,
        userId: widget.user.id,
      );
      await _loadFeed(showLoader: false);
      if (!mounted) return;
      showCommunitySnack(
        context,
        pinned ? 'Publication épinglée.' : 'Publication désépinglée.',
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _react(Post post, CommunityReaction? reaction) async {
    final target = reaction ?? post.myReaction;
    if (target == null) return;
    try {
      await _repository.toggleReaction(
        postId: post.id,
        userId: widget.user.id,
        reaction: target,
        actorName: _authorName,
      );
      await _loadFeed(showLoader: false);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openComments(Post post) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CommentsSheet(
        post: post,
        currentUser: widget.user,
        repository: _repository,
      ),
    );
    if (!mounted) return;
    await _loadFeed(showLoader: false);
  }

  Future<void> _reportPost(Post post) async {
    final reported = await showReportSheet(
      context,
      repository: _repository,
      reporterId: widget.user.id,
      reporterName: _authorName,
      targetType: ReportTargetType.post,
      targetId: post.id,
    );
    if (reported && mounted) {
      showCommunitySnack(context, 'Signalement envoyé au propriétaire.');
    }
  }

  Future<void> _bookmark(Post post) async {
    String? collectionId;
    if (!post.bookmarkedByMe) {
      try {
        final collections = await _repository.getCollections(widget.user.id);
        if (collections.isNotEmpty && mounted) {
          final selected = await showDialog<String>(
            context: context,
            builder: (dialogContext) => SimpleDialog(
              title: const Text('Enregistrer dans…'),
              children: [
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, ''),
                  child: const Text('Aucune collection'),
                ),
                for (final collection in collections)
                  SimpleDialogOption(
                    onPressed: () =>
                        Navigator.pop(dialogContext, collection.id),
                    child: Text(collection.name),
                  ),
              ],
            ),
          );
          if (selected == null) return;
          if (selected.isNotEmpty) collectionId = selected;
        }
      } catch (_) {
        // Sans collection, l'enregistrement simple reste possible.
      }
    }

    try {
      final saved = await _repository.toggleBookmark(
        postId: post.id,
        userId: widget.user.id,
        collectionId: collectionId,
      );
      if (!mounted) return;
      showCommunitySnack(
        context,
        saved ? 'Publication enregistrée.' : 'Retirée des enregistrements.',
      );
      await _loadFeed(showLoader: false);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _share(Post post) async {
    final link = 'fittrack://community/post/${post.id}';
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Partager la publication',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: Text(
                    link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Lien interne au module'),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copier le texte'),
                onTap: () => Navigator.pop(sheetContext, 'text'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_rounded),
                title: const Text('Copier le lien'),
                onTap: () => Navigator.pop(sheetContext, 'link'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;

    final payload = action == 'link'
        ? link
        : '${post.content}\n\n$link';
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: payload));
    } catch (_) {
      // Certains navigateurs (mode web sans permission) refusent le
      // presse-papiers : le partage reste possible via le lien interne.
      copied = false;
    }
    try {
      await _repository.registerShare(
        postId: post.id,
        userId: widget.user.id,
      );
      await _loadFeed(showLoader: false);
    } catch (_) {
      // Le partage local reste utile même si le compteur échoue.
    }
    if (!mounted) return;
    showCommunitySnack(
      context,
      copied
          ? 'Contenu copié dans le presse-papiers.'
          : 'Partage enregistré. Lien interne : $link',
    );
  }

  Future<void> _viewReactions(Post post) async {
    try {
      final reactions = await _repository.getReactions(post.id);
      if (!mounted) return;
      await showReactionList(
        context,
        title: 'Réactions · ${post.authorName}',
        reactions: reactions,
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _votePoll(Post post, PollOption option) async {
    try {
      await _repository.votePoll(
        postId: post.id,
        optionId: option.id,
        userId: widget.user.id,
        actorName: _authorName,
      );
      await _loadFeed(showLoader: false);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _publishDraft(Post post) async {
    try {
      await _repository.publishDraft(
        postId: post.id,
        userId: widget.user.id,
      );
      await _loadFeed(showLoader: false);
      if (!mounted) return;
      showCommunitySnack(context, 'Brouillon publié.');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openNotifications() async {
    await showCommunityNotificationsSheet(
      context,
      repository: _repository,
      userId: widget.user.id,
    );
    if (!mounted) return;
    await _refreshNotifications();
    await _loadFeed(showLoader: false);
  }

  Future<void> _openBookmarks() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityBookmarksScreen(
          user: widget.user,
          repository: _repository,
        ),
      ),
    );
    if (!mounted) return;
    await _loadFeed(showLoader: false);
  }

  Future<void> _openDrafts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityDraftsScreen(
          user: widget.user,
          repository: _repository,
        ),
      ),
    );
    if (!mounted) return;
    await _loadFeed(showLoader: false);
  }

  Future<void> _openModeration() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityModerationScreen(
          user: widget.user,
          repository: _repository,
        ),
      ),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is CommunityException
        ? error.message
        : communityErrorMessage(error);
    showCommunitySnack(context, message);
  }

  Future<void> _searchPosts() async {
    _searchDialogController.text = _searchQuery;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rechercher'),
        content: TextField(
          controller: _searchDialogController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Mot-clé, #hashtag ou @mention',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('Effacer'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _searchDialogController.text),
            child: const Text('Rechercher'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _searchQuery = result.trim());
    }
  }

  @override
  void dispose() {
    _searchDialogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visiblePosts = _visiblePosts;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Publications',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Partage tes repas, progrès et astuces avec la communauté.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _notificationButton(context),
                PopupMenuButton<String>(
                  tooltip: 'Plus d’options',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    switch (value) {
                      case 'bookmarks':
                        _openBookmarks();
                      case 'drafts':
                        _openDrafts();
                      case 'moderation':
                        _openModeration();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'bookmarks',
                      child: Text('Enregistrements'),
                    ),
                    PopupMenuItem(
                      value: 'drafts',
                      child: Text('Brouillons'),
                    ),
                    PopupMenuItem(
                      value: 'moderation',
                      child: Text('Modération de mon contenu'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _createPost,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Publier'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _themeChip(null, 'Tout'),
                  for (final option in PostTheme.values)
                    _themeChip(option, option.label),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  tooltip: 'Rechercher des publications',
                  onPressed: _searchPosts,
                  icon: Icon(
                    _searchQuery.isEmpty
                        ? Icons.search_rounded
                        : Icons.search_off_rounded,
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        label: Text(_searchQuery),
                        onDeleted: () => setState(() => _searchQuery = ''),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                PopupMenuButton<_FeedSort>(
                  tooltip: 'Trier les publications',
                  onSelected: (value) => setState(() => _sort = value),
                  icon: const Icon(Icons.swap_vert_rounded),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _FeedSort.newest,
                      child: Text('Plus récentes'),
                    ),
                    PopupMenuItem(
                      value: _FeedSort.oldest,
                      child: Text('Plus anciennes'),
                    ),
                    PopupMenuItem(
                      value: _FeedSort.mostLiked,
                      child: Text('Plus aimées'),
                    ),
                    PopupMenuItem(
                      value: _FeedSort.mostCommented,
                      child: Text('Plus commentées'),
                    ),
                    PopupMenuItem(
                      value: _FeedSort.trending,
                      child: Text('Tendances'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${visiblePosts.length} publication${visiblePosts.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _sort == _FeedSort.trending
                      ? 'Tendances du moment'
                      : _selectedTheme?.label ?? 'Tous les thèmes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(context, visiblePosts)),
          ],
        ),
      ),
    );
  }

  Widget _notificationButton(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications du module',
          onPressed: _openNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        if (_unreadNotifications > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _themeChip(PostTheme? option, String label) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = _selectedTheme == option;

    final icon = option == null ? Icons.grid_view_rounded : option.icon;
    final accent = option == null ? colors.onSurfaceVariant : option.color;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 16,
          color: selected ? colors.onPrimary : accent,
        ),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? colors.onPrimary : colors.onSurfaceVariant,
        ),
        backgroundColor: colors.surfaceContainerHighest,
        selectedColor: colors.primary,
        onSelected: (_) {
          if (selected) return;
          setState(() => _selectedTheme = option);
          _loadFeed();
        },
      ),
    );
  }

  List<Post> get _visiblePosts {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _posts
        .where(
          (post) =>
              query.isEmpty ||
              post.content.toLowerCase().contains(query) ||
              post.authorName.toLowerCase().contains(query) ||
              post.theme.label.toLowerCase().contains(query) ||
              post.hashtags.any(
                (tag) => '#${tag.toLowerCase()}'.contains(query),
              ) ||
              post.mentions.any(
                (mention) => '@${mention.toLowerCase()}'.contains(query),
              ),
        )
        .toList();
    switch (_sort) {
      case _FeedSort.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _FeedSort.oldest:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _FeedSort.mostLiked:
        filtered.sort((a, b) => b.likeCount.compareTo(a.likeCount));
      case _FeedSort.mostCommented:
        filtered.sort((a, b) => b.commentCount.compareTo(a.commentCount));
      case _FeedSort.trending:
        filtered.sort(
          (a, b) => _trendingScore(b).compareTo(_trendingScore(a)),
        );
    }
    return filtered;
  }

  double _trendingScore(Post post) {
    final ageHours = DateTime.now().difference(post.createdAt).inMinutes / 60.0;
    final freshness = ageHours < 0 ? 0.0 : 1 / (1 + ageHours / 24);
    return post.likeCount * 3.0 +
        post.commentCount * 2.0 +
        post.shareCount * 2.0 +
        freshness * 6 +
        (post.isPinned ? 4 : 0);
  }

  Widget _buildBody(BuildContext context, List<Post> visiblePosts) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _loadFeed(),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (visiblePosts.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadFeed(showLoader: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 40),
          children: [_emptyState(context)],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadFeed(showLoader: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        itemCount: visiblePosts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final post = visiblePosts[index];
          return PostCard(
            post: post,
            currentUserId: widget.user.id,
            onReact: (reaction) => _react(post, reaction),
            onComment: () => _openComments(post),
            onEdit: () => _editPost(post),
            onDelete: () => _deletePost(post),
            onPin: () => _togglePin(post),
            onReport: () => _reportPost(post),
            onBookmark: () => _bookmark(post),
            onShare: () => _share(post),
            onViewReactions: () => _viewReactions(post),
            onVotePoll: (option) => _votePoll(post, option),
            onPublishDraft: () => _publishDraft(post),
            onHashtagTap: (tag) =>
                setState(() => _searchQuery = '#$tag'),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.forum_outlined, size: 40, color: colors.primary),
        ),
        const SizedBox(height: 16),
        Text(
          'Aucune publication',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _selectedTheme == null
              ? 'Sois le premier à partager un repas, une séance ou une réussite.'
              : 'Aucune publication dans le thème « ${_selectedTheme!.label} » pour le moment.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _createPost,
          icon: const Icon(Icons.add),
          label: const Text('Créer une publication'),
        ),
      ],
    );
  }
}
