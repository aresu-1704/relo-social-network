import 'package:dio/dio.dart';
import 'package:relo/models/post.dart';
import 'package:relo/models/comment.dart';

class PostService {
  final Dio _dio;

  PostService(this._dio);

  /// Lấy danh sách bài đăng (newsfeed)
  Future<List<Post>> getFeed({int skip = 0, int limit = 20}) async {
    try {
      final response = await _dio.get(
        'posts/feed',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.data is List) {
        return (response.data as List)
            .map((json) => Post.fromJson(json))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw Exception('Failed to fetch feed: $e');
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }

  /// Tạo bài đăng mới
  Future<Post> createPost({
    required String content,
    List<String>? mediaBase64,
  }) async {
    try {
      final response = await _dio.post(
        'posts',
        data: {
          'content': content,
          'mediaBase64': mediaBase64 ?? [],
        },
      );

      return Post.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to create post: ${e.response?.data ?? e.message}');
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }

  /// Thả reaction vào bài đăng
  Future<Post> reactToPost({
    required String postId,
    required String reactionType,
  }) async {
    try {
      final response = await _dio.post(
        'posts/$postId/react',
        data: {'reaction_type': reactionType},
      );

      return Post.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to react: ${e.response?.data ?? e.message}');
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }

  /// Tạo comment cho bài đăng
  Future<Comment> createComment({
    required String postId,
    required String content,
  }) async {
    try {
      final response = await _dio.post(
        'posts/$postId/comments',
        data: {'content': content},
      );

      return Comment.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to comment: ${e.response?.data ?? e.message}');
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }

  /// Lấy danh sách comments của bài đăng
  Future<List<Comment>> getComments({
    required String postId,
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        'posts/$postId/comments',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.data is List) {
        return (response.data as List)
            .map((json) => Comment.fromJson(json))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw Exception('Failed to fetch comments: $e');
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }

  /// Xóa bài đăng
  Future<void> deletePost(String postId) async {
    try {
      await _dio.delete('posts/$postId');
    } on DioException catch (e) {
      throw Exception('Failed to delete post: ${e.response?.data ?? e.message}');
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }
}
