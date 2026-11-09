import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../data/community_repository.dart';
import '../models/post.dart';
import '../utils/community_formatters.dart';
import '../widgets/community_dialogs.dart';
import '../widgets/post_composer_sheet.dart';

class CommunityDraftsScreen extends StatefulWidget {
  const CommunityDraftsScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final User user;
  final CommunityRepository repository;

  @override
  State<CommunityDraftsScreen> createState() => _CommunityDraftsScreenState();
}

class _CommunityDraftsScreenState extends State<CommunityDraftsScreen> {
  List<Post> _drafts = [];
  bool _loading = true;

  String get _authorName =>
      '${widget.user.firstName} ${widget.user.lastName}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final drafts = await widget.repository.getDrafts(userId: widget.user.id);
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  Future<void> _publish(Post draft) async {
    try {
      await widget.repository.publishDraft(
        postId: draft.id,
        userId: widget.user.id,
      );
      if (!mounted) return;
      showCommunitySnack(context, 'Brouillon publié.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  Future<void> _edit(Post draft) async {
    final result = await showModalBottomSheet<PostDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PostComposerSheet(
        isEditing: true,
        initialContent: draft.content,
        initialTheme: draft.theme,
        initialImageBytes: draft.imageBytes,
        initialVideoBytes: draft.videoBytes,
        initialVideoName: draft.videoName,
        initialAllowAnonymousComments: draft.allowAnonymousComments,
        initialIsDraft: true,
        repository: widget.repository,
        currentUserId: widget.user.id,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await widget.repository.updatePost(
        postId: draft.id,
        userId: widget.user.id,
        content: result.content,
        theme: result.theme,
        isDraft: result.isDraft,
        allowAnonymousComments: result.allowAnonymousComments,
        imageBytes: result.imageBytes,
        clearImage: result.clearImage,
        videoBytes: result.videoBytes,
        videoName: result.videoName,
        clearVideo: result.clearVideo,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  Future<void> _delete(Post draft) async {
    final confirmed = await showCommunityConfirmDialog(
      context,
      title: 'Supprimer le brouillon ?',
      message: 'Le brouillon sera définitivement supprimé.',
    );
    if (!confirmed) return;
    try {
      await widget.repository.deletePost(
        postId: draft.id,
        userId: widget.user.id,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  Future<void> _createDraft() async {
    final result = await showModalBottomSheet<PostDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PostComposerSheet(
        repository: widget.repository,
        currentUserId: widget.user.id,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await widget.repository.createPost(
        userId: widget.user.id,
        authorName: _authorName,
        authorAvatarPath: widget.user.profilePicturePath,
        content: result.content,
        theme: result.theme,
        imageBytes: result.imageBytes,
        videoBytes: result.videoBytes,
        videoName: result.videoName,
        isDraft: true,
        allowAnonymousComments: result.allowAnonymousComments,
        pollQuestion: result.pollQuestion,
        pollOptions: result.pollOptions,
        pollEndsAt: result.pollEndsAt,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brouillons'),
        actions: [
          IconButton(
            tooltip: 'Nouveau brouillon',
            onPressed: _createDraft,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
          ? _emptyState(context)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _drafts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final draft = _drafts[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                draft.theme.icon,
                                size: 15,
                                color: draft.theme.color,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                draft.theme.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: draft.theme.color,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Modifié ${formatPostTime(draft.updatedAt)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            draft.content,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                          if (draft.imageBytes != null ||
                              draft.videoBytes != null ||
                              draft.poll != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (draft.imageBytes != null)
                                  const Chip(
                                    avatar: Icon(Icons.image_outlined, size: 14),
                                    label: Text('Photo'),
                                  ),
                                if (draft.videoBytes != null)
                                  const Chip(
                                    avatar: Icon(
                                      Icons.videocam_outlined,
                                      size: 14,
                                    ),
                                    label: Text('Vidéo'),
                                  ),
                                if (draft.poll != null)
                                  const Chip(
                                    avatar: Icon(Icons.poll_outlined, size: 14),
                                    label: Text('Sondage'),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => _edit(draft),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Modifier'),
                              ),
                              TextButton.icon(
                                onPressed: () => _delete(draft),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                label: const Text('Supprimer'),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: () => _publish(draft),
                                icon: const Icon(
                                  Icons.send_rounded,
                                  size: 18,
                                ),
                                label: const Text('Publier'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
              Icons.edit_note_rounded,
              size: 42,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun brouillon',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enregistre une publication en brouillon pour la terminer plus '
              'tard.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _createDraft,
              icon: const Icon(Icons.add),
              label: const Text('Créer un brouillon'),
            ),
          ],
        ),
      ),
    );
  }
}
