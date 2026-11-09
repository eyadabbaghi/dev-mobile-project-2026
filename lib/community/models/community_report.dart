import 'comment_insights.dart';

enum ReportTargetType {
  post('post', 'Publication'),
  comment('comment', 'Commentaire');

  const ReportTargetType(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static ReportTargetType fromStorage(String? value) {
    return ReportTargetType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => ReportTargetType.post,
    );
  }
}

enum ReportReason {
  spam('spam', 'Spam ou publicité'),
  harassment('harassment', 'Harcèlement'),
  hate('hate', 'Discours haineux'),
  violence('violence', 'Violence'),
  nudity('nudity', 'Contenu explicite'),
  misinformation('misinformation', 'Désinformation'),
  other('other', 'Autre');

  const ReportReason(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static ReportReason fromStorage(String? value) {
    for (final reason in ReportReason.values) {
      if (reason.storageValue == value) return reason;
    }
    return ReportReason.other;
  }
}

enum ReportStatus {
  pending('pending', 'En attente'),
  reviewed('reviewed', 'Examiné'),
  dismissed('dismissed', 'Ignoré');

  const ReportStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static ReportStatus fromStorage(String? value) {
    for (final status in ReportStatus.values) {
      if (status.storageValue == value) return status;
    }
    return ReportStatus.pending;
  }
}

class ContentReport {
  const ContentReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reporterId,
    required this.reason,
    required this.createdAt,
    this.reporterName,
    this.details = '',
    this.status = ReportStatus.pending,
    this.targetPreview = '',
    this.targetOwnerId,
    this.resolutionNote,
  });

  final String id;
  final ReportTargetType targetType;
  final String targetId;
  final String reporterId;
  final ReportReason reason;
  final DateTime createdAt;
  final String? reporterName;
  final String details;
  final ReportStatus status;
  final String targetPreview;
  final String? targetOwnerId;
  final String? resolutionNote;

  factory ContentReport.fromDatabaseMap(Map<String, Object?> map) {
    return ContentReport(
      id: map['id'] as String,
      targetType: ReportTargetType.fromStorage(map['target_type'] as String?),
      targetId: map['target_id'] as String,
      reporterId: map['reporter_id'] as String,
      reason: ReportReason.fromStorage(map['reason'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      reporterName: map['reporter_name'] as String?,
      details: (map['details'] as String?) ?? '',
      status: ReportStatus.fromStorage(map['status'] as String?),
      targetPreview: (map['target_preview'] as String?) ?? '',
      targetOwnerId: map['target_owner_id'] as String?,
      resolutionNote: map['resolution_note'] as String?,
    );
  }
}

enum ContentFlagStatus {
  pending('pending', 'À vérifier'),
  dismissed('dismissed', 'Ignoré'),
  confirmed('confirmed', 'Confirmé');

  const ContentFlagStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static ContentFlagStatus fromStorage(String? value) {
    for (final status in ContentFlagStatus.values) {
      if (status.storageValue == value) return status;
    }
    return ContentFlagStatus.pending;
  }
}

class ContentFlag {
  const ContentFlag({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.ownerId,
    required this.category,
    required this.explanation,
    required this.createdAt,
    this.postOwnerId,
    this.source = AiSource.local,
    this.status = ContentFlagStatus.pending,
    this.targetPreview = '',
  });

  final String id;
  final ReportTargetType targetType;
  final String targetId;
  final String ownerId;
  final String category;
  final String explanation;
  final DateTime createdAt;
  final String? postOwnerId;
  final AiSource source;
  final ContentFlagStatus status;
  final String targetPreview;

  factory ContentFlag.fromDatabaseMap(Map<String, Object?> map) {
    return ContentFlag(
      id: map['id'] as String,
      targetType: ReportTargetType.fromStorage(map['target_type'] as String?),
      targetId: map['target_id'] as String,
      ownerId: map['owner_id'] as String,
      category: (map['category'] as String?) ?? 'Contenu sensible',
      explanation: (map['explanation'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      postOwnerId: map['post_owner_id'] as String?,
      source: AiSource.fromStorage(map['source'] as String?),
      status: ContentFlagStatus.fromStorage(map['status'] as String?),
      targetPreview: (map['target_preview'] as String?) ?? '',
    );
  }
}

class ModerationAction {
  const ModerationAction({
    required this.id,
    required this.actorId,
    required this.action,
    required this.createdAt,
    this.targetType,
    this.targetId,
    this.note = '',
  });

  final String id;
  final String actorId;
  final String action;
  final DateTime createdAt;
  final ReportTargetType? targetType;
  final String? targetId;
  final String note;

  factory ModerationAction.fromDatabaseMap(Map<String, Object?> map) {
    return ModerationAction(
      id: map['id'] as String,
      actorId: map['actor_id'] as String,
      action: map['action'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      targetType: map['target_type'] == null
          ? null
          : ReportTargetType.fromStorage(map['target_type'] as String?),
      targetId: map['target_id'] as String?,
      note: (map['note'] as String?) ?? '',
    );
  }
}
