import 'package:dio/dio.dart';
import 'package:relo/models/post.dart';

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
    List<String>? filePaths,
  }) async {
    try {
      // Tạo FormData
      final formData = FormData();
      
      // Thêm content (luôn gửi, ngay cả khi rỗng)
      formData.fields.add(MapEntry('content', content ?? ''));
      
      // Thêm files nếu có
      if (filePaths != null && filePaths.isNotEmpty) {
        for (final path in filePaths) {
          formData.files.add(
            MapEntry(
              'files',
              await MultipartFile.fromFile(path),
            ),
          );
        }
      }
      
      print('📤 Sending post: content="${content ?? ''}", files count: ${filePaths?.length ?? 0}');
      
      final response = await _dio.post(
        'posts',
        data: formData,
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

  /// Cập nhật bài đăng
  Future<Post> updatePost({
    required String postId,
    required String content,
    List<String>? existingImageUrls,
    List<String>? newFilePaths,
  }) async {
    try {
      final formData = FormData();
      
      // Add content
      formData.fields.add(MapEntry('content', content));
      
      // Add existing image URLs to keep
      if (existingImageUrls != null) {
        for (var url in existingImageUrls) {
          formData.fields.add(MapEntry('existing_image_urls', url));
        }
      }
      
      // Add new files to upload
      if (newFilePaths != null) {
        for (var filePath in newFilePaths) {
          final file = await MultipartFile.fromFile(
            filePath,
            filename: filePath.split('/').last,
          );
          formData.files.add(MapEntry('files', file));
        }
      }

      final response = await _dio.put(
        'posts/$postId',
        data: formData,
      );

      return Post.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to update post: ${e.response?.data ?? e.message}');
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
