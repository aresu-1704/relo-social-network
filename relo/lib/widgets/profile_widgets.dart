import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

/// Profile Statistics Widget
class ProfileStatistics extends StatelessWidget {
  final int friendCount;
  final int postCount;
  final int followerCount;
  final VoidCallback? onFriendsClick;
  final VoidCallback? onPostsClick;
  final VoidCallback? onFollowersClick;

  const ProfileStatistics({
    Key? key,
    required this.friendCount,
    required this.postCount,
    this.followerCount = 0,
    this.onFriendsClick,
    this.onPostsClick,
    this.onFollowersClick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            context,
            'Bạn bè',
            friendCount.toString(),
            Icons.people,
            onFriendsClick,
          ),
          _buildDivider(),
          _buildStatItem(
            context,
            'Bài viết',
            postCount.toString(),
            Icons.article,
            onPostsClick,
          ),
          _buildDivider(),
          _buildStatItem(
            context,
            'Theo dõi',
            followerCount.toString(),
            Icons.favorite,
            onFollowersClick,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: Color(0xFF7C3AED), size: 28),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 50,
      width: 1,
      color: Colors.grey[300],
    );
  }
}

/// Profile Avatar Widget with Edit Button
class ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final bool isOwnProfile;
  final VoidCallback? onEditPressed;
  final double radius;

  const ProfileAvatar({
    Key? key,
    this.avatarUrl,
    this.isOwnProfile = false,
    this.onEditPressed,
    this.radius = 50,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isOwnProfile ? onEditPressed : null,
      child: Stack(
        children: [
          Hero(
            tag: 'profile_avatar',
            child: CircleAvatar(
              radius: radius,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: radius - 3,
                backgroundColor: Colors.grey[300],
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(avatarUrl!)
                    : null,
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? Icon(
                        Icons.person,
                        size: radius,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
          if (isOwnProfile)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF7C3AED),
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
    );
  }
}

/// Loading Shimmer for Profile
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Background shimmer
            Container(
              height: 200,
              color: Colors.white,
            ),
            
            SizedBox(height: 20),
            
            // Avatar shimmer
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
            ),
            
            SizedBox(height: 16),
            
            // Name shimmer
            Container(
              width: 150,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            
            SizedBox(height: 8),
            
            // Bio shimmer
            Container(
              width: 200,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Statistics shimmer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                3,
                (index) => Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: 50,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Buttons shimmer
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Action Button
class ProfileActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;

  const ProfileActionButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: textColor ?? Colors.white),
      label: Text(
        label,
        style: TextStyle(color: textColor ?? Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Color(0xFF7C3AED),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    );
  }
}

/// Info Row Widget
class ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;

  const ProfileInfoRow({
    Key? key,
    required this.icon,
    required this.text,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: iconColor ?? Colors.grey[600],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty State Widget
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyStateWidget({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}
