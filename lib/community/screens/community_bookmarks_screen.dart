import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../data/community_repository.dart';
import '../models/post.dart';
import '../utils/community_formatters.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/community_dialogs.dart';

class CommunityBookmarksScreen extends StatefulWidget {
  const CommunityBookmarksScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final User user;
  final CommunityRepository repository;

  @override
  State<CommunityBookmarksScreen> createState() =>
      _CommunityBookmarksScreenState();
}

class _CommunityBookmarksScreenState extends State<CommunityBookmarksScreen> {
  List<BookmarkCollection> _collections = [];
  List<Post> _posts = [];
  String? _collectionId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final collections = await widget.repository.getCollections(
        widget.user.id,
      );
      final posts = await widget.repository.getBookmarkedPosts(
        currentUserId: widget.user.id,
        collectionId: _collectionId,
      );
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _posts = posts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  Future<void> _createCollection() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouvelle collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Nom de la collection',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.repository.createCollection(
        userId: widget.user.id,
        name: name,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  Future<void> _deleteCollection(BookmarkCollection collection) async {
    final confirmed = await showCommunityConfirmDialog(
      context,
      title: 'Supprimer la collection ?',
      message:
          'Les publications enregistrées resteront dans tes enregistrements, '
          'mais la collection « ${collection.name} » sera supprimée.',
    );
    if (!confirmed) return;
    try {
      await widget.repository.deleteCollection(
        collectionId: collection.id,
        userId: widget.user.id,
      );
      if (_collectionId == collection.id) _collectionId = null;
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  Future<void> _removeBookmark(Post post) async {
    try {
      await widget.repository.toggleBookmark(
        postId: post.id,
        userId: widget.user.id,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
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
        repository: widget.repository,
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = _collections
        .where((collection) => collection.id == _collectionId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enregistrements'),
        actions: [
          if (selected != null)
            IconButton(
              tooltip: 'Supprimer la collection',
              onPressed: () => _deleteCollection(selected),
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            tooltip: 'Nouvelle collection',
            onPressed: _createCollection,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Tout'),
                    selected: _collectionId == null,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => _collectionId = null);
                      _load();
                    },
                  ),
                ),
                for (final collection in _collections)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        '${collection.name} (${collection.itemCount})',
                      ),
                      selected: _collectionId == collection.id,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _collectionId = collection.id);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                ? _emptyState(context)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _posts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final post = _posts[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => _openComments(post),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            colors.primaryContainer,
                                        foregroundColor:
                                            colors.onPrimaryContainer,
                                        child: Text(
                                          initialsOf(post.authorName),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          post.authorName,
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      Icon(
                                        post.theme.icon,
                                        size: 15,
                                        color: post.theme.color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        post.theme.label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: post.theme.color,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    post.content,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        formatPostTime(post.createdAt),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Retirer des enregistrements',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _removeBookmark(
                                          post.copyWith(
                                            bookmarkedByMe: true,
                                          ),
                                        ),
                                        icon: Icon(
                                          Icons.bookmark_rounded,
                                          color: colors.primary,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Commentaires',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _openComments(post),
                                        icon: Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 42,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun enregistrement',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enregistre des publications depuis le fil pour les retrouver ici.',
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
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    for (final element in this) {
      return element;
    }
    return null;
  }
}
