import 'package:flutter/material.dart';
import 'package:relo/services/service_locator.dart';
import '../services/user_service.dart';
import '../models/user.dart';
import 'dart:collection';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late Future<List<User>> _friendsFuture;
  final UserService _userService = ServiceLocator.userService;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _userService.getFriends();
  }

  // Helper function to group friends by the first letter of their display name
  Map<String, List<User>> _groupFriends(List<User> friends) {
    // Sort friends alphabetically by display name
    friends.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

    final Map<String, List<User>> groupedFriends = LinkedHashMap();

    for (var friend in friends) {
      if (friend.displayName.isNotEmpty) {
        final firstLetter = friend.displayName[0].toUpperCase();
        if (groupedFriends[firstLetter] == null) {
          groupedFriends[firstLetter] = [];
        }
        groupedFriends[firstLetter]!.add(friend);
      }
    }
    return groupedFriends;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _friendsFuture = _userService.getFriends();
          });
        },
        child: FutureBuilder<List<User>>(
          future: _friendsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Lỗi: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Bạn chưa có người bạn nào.'));
            }

            final friends = snapshot.data!;
            final groupedFriends = _groupFriends(friends);
            final sortedKeys = groupedFriends.keys.toList()..sort();

            return ListView.builder(
              itemCount: sortedKeys.length,
              itemBuilder: (context, index) {
                final letter = sortedKeys[index];
                final friendsInGroup = groupedFriends[letter]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        letter,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...friendsInGroup.map((friend) => _buildFriendTile(friend)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFriendTile(User friend) {
    return InkWell(
      onTap: () {
        // TODO: Navigate to the message screen for this user
        // Navigator.push(context, MaterialPageRoute(builder: (context) => MessageScreen(userId: friend.id)));
        print("Navigate to chat with ${friend.displayName}");
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(
                friend.displayName.isNotEmpty
                    ? friend.displayName[0].toUpperCase()
                    : '#',
              ),
              // You can replace this with an actual image if you have avatar URLs
              // backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                friend.displayName,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.call_outlined, color: Colors.grey),
              onPressed: () {
                // TODO: Implement phone call functionality
              },
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined, color: Colors.grey),
              onPressed: () {
                // TODO: Implement video call functionality
              },
            ),
          ],
        ),
      ),
    );
  }
}
