import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class ProfileHeader extends StatelessWidget {
  final String? backgroundUrl;
  final String? avatarUrl;
  final String displayName;
  final String username;
  final bool isOwnProfile;
  final String? tempAvatarPath;
  final String? tempBackgroundPath;
  final VoidCallback onEditProfile;
  final VoidCallback onAvatarTap;
  final VoidCallback onBackgroundTap;

  const ProfileHeader({
    Key? key,
    required this.backgroundUrl,
    required this.avatarUrl,
    required this.displayName,
    required this.username,
    required this.isOwnProfile,
    required this.tempAvatarPath,
    required this.tempBackgroundPath,
    required this.onEditProfile,
    required this.onAvatarTap,
    required this.onBackgroundTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: isOwnProfile ? onBackgroundTap : null,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              image: tempBackgroundPath != null
                  ? DecorationImage(
                      image: FileImage(File(tempBackgroundPath!)),
                      fit: BoxFit.cover,
                    )
                  : (backgroundUrl != null && backgroundUrl!.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(backgroundUrl!),
                            fit: BoxFit.cover,
                          )
                        : null),
              gradient:
                  (tempBackgroundPath == null &&
                      (backgroundUrl == null || backgroundUrl!.isEmpty))
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF9B59B6), Color(0xFF7A2FC0)],
                    )
                  : null,
            ),
            child:
                isOwnProfile &&
                    tempBackgroundPath == null &&
                    (backgroundUrl == null || backgroundUrl!.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 50,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Thêm ảnh bìa',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: isOwnProfile ? onAvatarTap : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 43,
                          backgroundImage: tempAvatarPath != null
                              ? FileImage(File(tempAvatarPath!))
                              : (avatarUrl != null && avatarUrl!.isNotEmpty
                                        ? CachedNetworkImageProvider(avatarUrl!)
                                        : null)
                                    as ImageProvider?,
                          child:
                              (tempAvatarPath == null &&
                                  (avatarUrl == null || avatarUrl!.isEmpty))
                              ? Icon(Icons.person, size: 50, color: Colors.grey)
                              : null,
                        ),
                      ),
                      if (isOwnProfile)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Color(0xFF7A2FC0),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '@$username',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isOwnProfile)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: IconButton(
              icon: Icon(Icons.edit, color: Colors.white),
              onPressed: onEditProfile,
            ),
          ),
      ],
    );
  }
}
