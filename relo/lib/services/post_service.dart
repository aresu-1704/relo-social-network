import 'package:dio/dio.dart';
import 'package:relo/models/post.dart';
import 'package:relo/models/comment.dart';
import 'dart:io';

class PostService {
  final Dio _dio;

  PostService(this._dio);

  /// Tạo bài viết mới
  Future<Post?> createPost({
    required String content,
    List<File>? mediaFiles,
  }) async {
    try {
      FormData formData = FormData();
      
      // Add text content
      formData.fields.add(MapEntry('content', content));
      
      // Add media files if any
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        for (int i = 0; i < mediaFiles.length; i++) {
          File file = mediaFiles[i];
          String fileName = file.path.split('/').last;
          formData.files.add(
            MapEntry(
              'files',
              await MultipartFile.fromFile(file.path, filename: fileName),
            ),
          );
        }
        formData.fields.add(MapEntry('type', 'media'));
      } else {
        formData.fields.add(MapEntry('type', 'text'));
      }
      
      final response = await _dio.post(
        'posts',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      
      if (response.data != null) {
        return Post.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      print('Error creating post: ${e.message}');
      throw Exception('Failed to create post: ${e.response?.data ?? e.message}');
    }
  }

  /// Upload ảnh Base64 cho profile/background (tương tự message_service.py)
  Future<String?> uploadImageBase64(String base64Image) async {
    try {
      final response = await _dio.post(
        'upload/image',
        data: {'image': base64Image},
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );
      
      if (response.data != null && response.data['url'] != null) {
        return response.data['url'];
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Lấy danh sách bài viết
  Future<List<Post>> getPosts({
    String? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        'posts',
        queryParameters: {
          if (userId != null) 'userId': userId,
          'limit': limit,
          'offset': offset,
        },
      );
      
      if (response.data is List) {
        return (response.data as List)
            .map((json) => Post.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting posts: $e');
      return [];
    }
  }

  /// Thêm reaction cho bài viết
  Future<bool> addReaction(String postId, String reactionType) async {
    try {
      await _dio.post('posts/$postId/reactions', data: {
        'type': reactionType,
      });
      return true;
    } catch (e) {
      print('Error adding reaction: $e');
      return false;
    }
  }

  /// Xóa reaction
  Future<bool> removeReaction(String postId) async {
    try {
      await _dio.delete('posts/$postId/reactions');
      return true;
    } catch (e) {
      print('Error removing reaction: $e');
      return false;
    }
  }

  /// Thêm comment (với real-time placeholder)
  Future<Comment?> addComment({
    required String postId,
    required String content,
    List<File>? mediaFiles,
  }) async {
    try {
      FormData formData = FormData();
      formData.fields.add(MapEntry('content', content));
      
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        for (var file in mediaFiles) {
          formData.files.add(
            MapEntry(
              'files',
              await MultipartFile.fromFile(file.path),
            ),
          );
        }
      }
      
      final response = await _dio.post(
        'posts/$postId/comments',
        data: formData,
      );
      
      if (response.data != null) {
        // TODO: Real time add vào ở đây
        // Khi có comment mới, broadcast qua WebSocket:
        // WebSocketService.instance.broadcast({
        //   'type': 'new_comment',
        //   'postId': postId,
        //   'comment': response.data
        // });
        
        return Comment.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error adding comment: $e');
      return null;
    }
  }

  /// Lấy comments của bài viết
  Future<List<Comment>> getComments(String postId, {int limit = 20, int offset = 0}) async {
    try {
      final response = await _dio.get(
        'posts/$postId/comments',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      
      if (response.data is List) {
        return (response.data as List)
            .map((json) => Comment.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  /// Xóa bài viết
  Future<bool> deletePost(String postId) async {
    try {
      await _dio.delete('posts/$postId');
      return true;
    } catch (e) {
      print('Error deleting post: $e');
      return false;
    }
  }
}
