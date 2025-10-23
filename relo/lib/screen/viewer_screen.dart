import 'package:flutter/material.dart';

class ViewerScreen extends StatelessWidget {
  const ViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Ảnh vừa chụp (demo bằng ảnh placeholder)
          Positioned.fill(
            child: Image.asset('assets/sample_photo.jpg', fit: BoxFit.cover),
          ),

          // Thanh công cụ trên
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _iconButton(
                        context,
                        Icons.close,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      _iconButton(context, Icons.crop),
                      const SizedBox(width: 8),
                      _iconButton(context, Icons.brush),
                      const SizedBox(width: 8),
                      _iconButton(context, Icons.text_fields),
                      const SizedBox(width: 8),
                      _iconButton(context, Icons.emoji_emotions_outlined),
                    ],
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Nút tải xuống & gửi
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã lưu ảnh vào máy')),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.download, size: 28),
                          SizedBox(height: 4),
                          Text('Lưu', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FloatingActionButton(
                      backgroundColor: Colors.white,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã gửi ảnh')),
                        );
                      },
                      child: const Icon(Icons.send, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(
    BuildContext context,
    IconData icon, {
    void Function()? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}
