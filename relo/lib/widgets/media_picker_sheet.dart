import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

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
    final permitted = await PhotoManager.requestPermissionExtend();
    if (!permitted.isAuth) {
      // Handle permission denial
      // Maybe show a message to the user
      PhotoManager.openSetting();
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
    );
    if (albums.isEmpty) return;

    final recentAssets = await albums.first.getAssetListRange(
      start: 0,
      end: 100, // Load 100 recent items
    );

    if (mounted) {
      setState(() {
        _assets = recentAssets;
      });
    }
  }

  void _send() async {
    if (_selectedAssets.isEmpty) return;

    final List<File> files = [];
    for (final asset in _selectedAssets) {
      final file = await asset.file;
      if (file != null) {
        files.add(file);
      }
    }
    widget.onPicked(files);
  }

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssets.contains(asset)) {
        _selectedAssets.remove(asset);
      } else {
        if (_selectedAssets.length < 30) {
          _selectedAssets.add(asset);
        }
      }
    });
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
                  : GridView.builder(
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
                            onTap: () {
                              // TODO: Open camera
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.black,
                                size: 36,
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
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7C3AED), width: 2),
              ),
              child: const Icon(Icons.check_circle, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
