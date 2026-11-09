import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base SQLite locale dédiée au module Publications & Commentaires.
///
/// Elle est séparée de la base principale et de celle des événements afin de
/// ne jamais modifier le schéma des autres modules.
class CommunityDatabase {
  CommunityDatabase._();

  static final CommunityDatabase instance = CommunityDatabase._();

  /// Pour les tests : mettre `inMemoryDatabasePath` avant le premier accès.
  static String? pathOverride;

  static const _fileName = 'fittrack_community.db';
  static const _version = 2;

  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final path = pathOverride ?? p.join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE posts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        author_name TEXT NOT NULL,
        author_avatar_path TEXT,
        content TEXT NOT NULL CHECK(length(trim(content)) > 0),
        image BLOB,
        video BLOB,
        video_name TEXT,
        theme TEXT NOT NULL,
        is_draft INTEGER NOT NULL DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        hashtags TEXT,
        mentions TEXT,
        allow_anonymous_comments INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE comments (
        id TEXT PRIMARY KEY,
        post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        parent_id TEXT REFERENCES comments(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL,
        author_name TEXT NOT NULL,
        author_avatar_path TEXT,
        content TEXT NOT NULL CHECK(length(trim(content)) > 0),
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_best_answer INTEGER NOT NULL DEFAULT 0,
        is_anonymous INTEGER NOT NULL DEFAULT 0,
        sentiment TEXT,
        is_flagged INTEGER NOT NULL DEFAULT 0,
        flag_reason TEXT,
        is_spam INTEGER NOT NULL DEFAULT 0,
        spam_reason TEXT,
        mentions TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Conservée pour la compatibilité des bases v1 et des anciens compteurs.
    await db.execute('''
      CREATE TABLE post_likes (
        post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (post_id, user_id)
      )
    ''');

    await _createV2Tables(db);

    await db.execute(
      'CREATE INDEX posts_created_idx ON posts(created_at DESC)',
    );
    await db.execute('CREATE INDEX posts_theme_idx ON posts(theme)');
    await db.execute('CREATE INDEX posts_draft_idx ON posts(is_draft)');
    await db.execute(
      'CREATE INDEX comments_post_idx ON comments(post_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX comments_parent_idx ON comments(parent_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE posts ADD COLUMN video BLOB',
      );
      await db.execute(
        'ALTER TABLE posts ADD COLUMN video_name TEXT',
      );
      await db.execute(
        'ALTER TABLE posts ADD COLUMN is_draft INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE posts ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE posts ADD COLUMN hashtags TEXT');
      await db.execute('ALTER TABLE posts ADD COLUMN mentions TEXT');
      await db.execute(
        'ALTER TABLE posts ADD COLUMN allow_anonymous_comments '
        'INTEGER NOT NULL DEFAULT 0',
      );

      await db.execute(
        'ALTER TABLE comments ADD COLUMN parent_id TEXT '
        'REFERENCES comments(id) ON DELETE CASCADE',
      );
      await db.execute(
        'ALTER TABLE comments ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE comments ADD COLUMN is_best_answer '
        'INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE comments ADD COLUMN is_anonymous '
        'INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE comments ADD COLUMN sentiment TEXT');
      await db.execute(
        'ALTER TABLE comments ADD COLUMN is_flagged INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE comments ADD COLUMN flag_reason TEXT');
      await db.execute(
        'ALTER TABLE comments ADD COLUMN is_spam INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE comments ADD COLUMN spam_reason TEXT');
      await db.execute('ALTER TABLE comments ADD COLUMN mentions TEXT');

      await _createV2Tables(db);

      await db.execute('''
        INSERT OR IGNORE INTO post_reactions (post_id, user_id, reaction, created_at)
        SELECT post_id, user_id, 'like', created_at FROM post_likes
      ''');

      await db.execute('CREATE INDEX posts_draft_idx ON posts(is_draft)');
      await db.execute(
        'CREATE INDEX comments_parent_idx ON comments(parent_id)',
      );
    }
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS post_reactions (
        post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL,
        reaction TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (post_id, user_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS comment_reactions (
        comment_id TEXT NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL,
        reaction TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (comment_id, user_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmark_collections (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks (
        user_id TEXT NOT NULL,
        post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        collection_id TEXT REFERENCES bookmark_collections(id)
          ON DELETE SET NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, post_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS polls (
        id TEXT PRIMARY KEY,
        post_id TEXT NOT NULL UNIQUE REFERENCES posts(id) ON DELETE CASCADE,
        question TEXT NOT NULL,
        ends_at INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS poll_options (
        id TEXT PRIMARY KEY,
        poll_id TEXT NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
        label TEXT NOT NULL,
        position INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS poll_votes (
        poll_id TEXT NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
        option_id TEXT NOT NULL REFERENCES poll_options(id)
          ON DELETE CASCADE,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (poll_id, user_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS post_shares (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reports (
        id TEXT PRIMARY KEY,
        target_type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        reporter_id TEXT NOT NULL,
        reporter_name TEXT,
        reason TEXT NOT NULL,
        details TEXT,
        status TEXT NOT NULL,
        resolution_note TEXT,
        created_at INTEGER NOT NULL,
        reviewed_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS content_flags (
        id TEXT PRIMARY KEY,
        target_type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        post_owner_id TEXT,
        category TEXT NOT NULL,
        explanation TEXT,
        source TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS moderation_actions (
        id TEXT PRIMARY KEY,
        actor_id TEXT NOT NULL,
        target_type TEXT,
        target_id TEXT,
        action TEXT NOT NULL,
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS community_notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        post_id TEXT,
        comment_id TEXT,
        actor_id TEXT,
        actor_name TEXT,
        message TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS community_profiles (
        user_id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        avatar_path TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS community_settings (
        user_id TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY (user_id, key)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS post_reactions_post_idx '
      'ON post_reactions(post_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS comment_reactions_comment_idx '
      'ON comment_reactions(comment_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS bookmarks_user_idx ON bookmarks(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS notifications_user_idx '
      'ON community_notifications(user_id, is_read)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS flags_owner_idx ON content_flags(owner_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS reports_target_idx '
      'ON reports(target_type, target_id)',
    );
  }

  /// Ferme la connexion (utile pour les tests et les changements de base).
  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening == null) return;
    final db = await opening;
    if (db.isOpen) await db.close();
  }
}
