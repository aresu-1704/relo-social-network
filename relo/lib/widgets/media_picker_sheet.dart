import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:relo/screen/camera_screen.dart';
import 'package:relo/utils/show_notification.dart';

class MediaPickerSheet extends StatefulWidget {
  final void Function(List<File> files) onPicked;

  const MediaPickerSheet({super.key, required this.onPicked});

  @override
  State<MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends State<MediaPickerSheet> {
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selectedAssets = [];

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    try {
      // 1️⃣ Xin quyền truy cập ảnh & video
      final permitted = await PhotoManager.requestPermissionExtend();

      if (!permitted.isAuth) {
        final openSettings = await ShowNotification.showCustomAlertDialog(
          context,
          message: "Ứng dụng cần quyền truy cập ảnh và video để gửi tệp",
          buttonText: "Mở cài đặt",
          buttonColor: const Color(0xFF7A2FC0),
        );

        if (openSettings == true) {
          await PhotoManager.openSetting(); // ⚙️ Mở Settings
          await Future.delayed(const Duration(seconds: 1));

          final after = await PhotoManager.requestPermissionExtend();
          if (!after.isAuth) {
            if (context.mounted) {
              await ShowNotification.showCustomAlertDialog(
                context,
                message: "Vẫn chưa có quyền truy cập ảnh/video.",
              );
              Navigator.pop(context); // 🚪 Thoát hoặc đóng sheet
            }
            return;
          }
        } else {
          if (context.mounted) Navigator.pop(context);
          return;
        }
      }

      // 2️⃣ Nếu đã có quyền → lấy album & assets
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
      );
      if (albums.isEmpty) return;

      final recentAssets = await albums.first.getAssetListRange(
        start: 0,
        end: 100,
      );

      if (mounted) {
        setState(() {
          _assets = recentAssets;
        });
      }
    } catch (e) {
      await ShowNotification.showCustomAlertDialog(
        context,
        message: "Không thể tải ảnh/video: $e",
      );
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _send() async {
    if (_selectedAssets.isEmpty) return;

    final List<File> files = [];
    int totalSize = 0;

    for (final asset in _selectedAssets) {
      final file = await asset.file;
      if (file != null) {
        final fileSize = await file.length(); // bytes
        totalSize += fileSize;
        files.add(file);
      }
    }

    const maxSize = 150 * 1024 * 1024; // 150 MB in bytes
    if (totalSize > maxSize) {
      await ShowNotification.showCustomAlertDialog(
        context,
        message: "Tổng dung lượng file vượt quá 150MB, vui lòng chọn ít hơn",
      );
      return;
    }

    widget.onPicked(files);
  }

  void _toggleSelection(AssetEntity asset) async {
    if (_selectedAssets.contains(asset)) {
      setState(() {
        _selectedAssets.remove(asset);
      });
    } else {
      if (_selectedAssets.length >= 30) {
        await ShowNotification.showCustomAlertDialog(
          context,
          message: "Chỉ được chọn tối đa 30 mục",
        );
        return;
      }
      setState(() {
        _selectedAssets.add(asset);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chọn ảnh hoặc video',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton(
                  onPressed: _send,
                  child: Text(
                    _selectedAssets.isEmpty
                        ? 'Gửi'
                        : 'Gửi (${_selectedAssets.length})',
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Gallery Grid
            Expanded(
              child: _assets.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : Scrollbar(
                      interactive: true,
                      thumbVisibility: true,
                      thickness: 10,
                      radius: const Radius.circular(12),
                      child: GridView.builder(
                        itemCount: _assets.length + 1, // +1 for camera button
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                        itemBuilder: (_, index) {
                          if (index == 0) {
                            // Camera button
                            return GestureDetector(
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CameraScreen(),
                                  ),
                                );
                                if (result != null && result is File) {
                                  widget.onPicked([result]);
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      color: const Color.fromARGB(
                                        255,
                                        112,
                                        112,
                                        112,
                                      ),
                                      size: 36,
                                    ),
                                    Text(
                                      "Mở máy ảnh",
                                      style: TextStyle(
                                        color: const Color.fromARGB(
                                          255,
                                          112,
                                          112,
                                          112,
                                        ),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          final asset = _assets[index - 1];
                          return AssetThumbnail(
                            asset: asset,
                            isSelected: _selectedAssets.contains(asset),
                            onTap: () => _toggleSelection(asset),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final bool isSelected;
  final VoidCallback onTap;

  const AssetThumbnail({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AssetEntityImage(
              asset,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(250),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Icon(Icons.error));
              },
            ),
          ),
          if (asset.type == AssetType.video)
            const Positioned(
              bottom: 4,
              right: 4,
              child: Icon(Icons.videocam, color: Colors.white, size: 20),
            ),
          if (isSelected)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7C3AED), width: 2),
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF7C3AED)),
            ),
        ],
      ),
    );
  }
}
