import 'api_client.dart';
import '../models/post.dart';

/// API client for community posts endpoints
class PostsApi {
  final ApiClient _client;

  PostsApi(this._client);

  /// Get community feed posts
  Future<List<Post>> getFeed({
    PostType? type,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (type != null) queryParams['type'] = type.name;

    final response = await _client.get<Map<String, dynamic>>(
      '/posts',
      queryParams: queryParams,
    );

    return (response['posts'] as List)
        .map((p) => Post.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Get a single post
  Future<Post> getPost(String id) async {
    final response = await _client.get<Map<String, dynamic>>('/posts/$id');
    return Post.fromJson(response['post'] as Map<String, dynamic>);
  }

  /// Create a new post
  Future<Post> createPost({
    required String content,
    PostType type = PostType.general,
    List<List<int>>? images,
    List<String>? imageFilenames,
  }) async {
    // If no images, simple JSON post
    if (images == null || images.isEmpty) {
      final response = await _client.post<Map<String, dynamic>>(
        '/posts',
        body: {
          'content': content,
          'type': type.name,
        },
      );
      return Post.fromJson(response['post'] as Map<String, dynamic>);
    }

    // With images, use multipart
    // Note: For multiple images, you'd typically upload separately or use a different approach
    // This is a simplified single-image example
    final response = await _client.uploadFile<Map<String, dynamic>>(
      '/posts',
      fieldName: 'image',
      fileBytes: images.first,
      filename: imageFilenames?.first ?? 'image.jpg',
      additionalFields: {
        'content': content,
        'type': type.name,
      },
    );
    return Post.fromJson(response['post'] as Map<String, dynamic>);
  }

  /// Update a post
  Future<Post> updatePost(String id, {required String content}) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/posts/$id',
      body: {'content': content},
    );
    return Post.fromJson(response['post'] as Map<String, dynamic>);
  }

  /// Delete a post
  Future<void> deletePost(String id) async {
    await _client.delete('/posts/$id');
  }

  /// Like a post
  Future<Post> likePost(String id) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/posts/$id/like',
    );
    return Post.fromJson(response['post'] as Map<String, dynamic>);
  }

  /// Unlike a post
  Future<Post> unlikePost(String id) async {
    final response = await _client.delete('/posts/$id/like');
    // delete returns void but for unlike we need the updated post
    // The API should return the updated post
    return Post.fromJson(
        (response as Map<String, dynamic>)['post'] as Map<String, dynamic>);
  }

  /// Get comments for a post
  Future<List<PostComment>> getComments(
    String postId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/posts/$postId/comments',
      queryParams: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    return (response['comments'] as List)
        .map((c) => PostComment.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Add a comment to a post
  Future<PostComment> addComment(String postId, String content) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/posts/$postId/comments',
      body: {'content': content},
    );
    return PostComment.fromJson(response['comment'] as Map<String, dynamic>);
  }

  /// Delete a comment
  Future<void> deleteComment(String postId, String commentId) async {
    await _client.delete('/posts/$postId/comments/$commentId');
  }
}
