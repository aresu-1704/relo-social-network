import 'package:dio/dio.dart';
import 'package:relo/models/comment.dart';

class CommentService {
  final Dio _dio;

  CommentService(this._dio);

  /// Lấy danh sách bình luận của một bài đăng
  Future<List<Comment>> getComments(
    String postId, {
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
      throw Exception('Không thể tải bình luận: ${e.message}');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định: $e');
    }
  }

  /// Tạo bình luận mới
  Future<Comment> createComment(String postId, String content) async {
    try {
      final response = await _dio.post(
        'posts/$postId/comments',
        data: {'content': content},
      );

      return Comment.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Không thể tạo bình luận: ${e.message}');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định: $e');
    }
  }

  /// Xóa bình luận
  Future<void> deleteComment(String commentId) async {
    try {
      await _dio.delete('comments/$commentId');
    } on DioException catch (e) {
      throw Exception('Không thể xóa bình luận: ${e.message}');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định: $e');
    }
  }

  /// Cập nhật bình luận
  Future<Comment> updateComment(String commentId, String content) async {
    try {
      final response = await _dio.put(
        'comments/$commentId',
        data: {'content': content},
      );

      return Comment.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Không thể cập nhật bình luận: ${e.message}');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định: $e');
    }
  }

  /// Lấy tổng số bình luận
  Future<int> getCommentCount(String postId) async {
    try {
      final response = await _dio.get('posts/$postId/comments/count');
      return response.data['count'] ?? 0;
    } on DioException {
      return 0;
    } catch (e) {
      return 0;
    }
  }
}
