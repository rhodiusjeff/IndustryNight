import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'post.g.dart';

/// Type of community post
enum PostType {
  /// General community post
  general,

  /// Looking for collaboration
  collaboration,

  /// Job opportunity
  job,

  /// Official announcement from admins
  announcement,
}

/// Post model representing a community feed post
@JsonSerializable(fieldRename: FieldRename.snake)
class Post extends Equatable {
  final String id;
  final String authorId;
  final String content;
  final List<String> imageUrls;

  @JsonKey(fromJson: _postTypeFromJson, toJson: _postTypeToJson)
  final PostType type;

  final bool isPinned;
  final bool isHidden;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Populated when fetching post details
  final User? author;

  /// Whether the current user has liked this post
  final bool? isLikedByCurrentUser;

  const Post({
    required this.id,
    required this.authorId,
    required this.content,
    this.imageUrls = const [],
    this.type = PostType.general,
    this.isPinned = false,
    this.isHidden = false,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.isLikedByCurrentUser,
  });

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

  Map<String, dynamic> toJson() => _$PostToJson(this);

  Post copyWith({
    String? id,
    String? authorId,
    String? content,
    List<String>? imageUrls,
    PostType? type,
    bool? isPinned,
    bool? isHidden,
    int? likeCount,
    int? commentCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? author,
    bool? isLikedByCurrentUser,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      type: type ?? this.type,
      isPinned: isPinned ?? this.isPinned,
      isHidden: isHidden ?? this.isHidden,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      author: author ?? this.author,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
    );
  }

  bool get hasImages => imageUrls.isNotEmpty;
  bool get isAnnouncement => type == PostType.announcement;

  @override
  List<Object?> get props => [
        id,
        authorId,
        content,
        imageUrls,
        type,
        isPinned,
        isHidden,
        likeCount,
        commentCount,
        createdAt,
        updatedAt,
        author,
        isLikedByCurrentUser,
      ];
}

/// Comment on a post
@JsonSerializable(fieldRename: FieldRename.snake)
class PostComment extends Equatable {
  final String id;
  final String postId;
  final String authorId;
  final String content;
  final DateTime createdAt;

  /// Populated when fetching comment details
  final User? author;

  const PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.author,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) =>
      _$PostCommentFromJson(json);

  Map<String, dynamic> toJson() => _$PostCommentToJson(this);

  @override
  List<Object?> get props => [id, postId, authorId, content, createdAt, author];
}

PostType _postTypeFromJson(String value) {
  return PostType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => PostType.general,
  );
}

String _postTypeToJson(PostType type) => type.name;
