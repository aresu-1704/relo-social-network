import 'package:flutter/material.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/models/user.dart';
import 'package:relo/screen/profile_screen.dart';
import 'package:shimmer/shimmer.dart';

class GroupMembersScreen extends StatefulWidget {
  final List<String> memberIds;
  final String groupName;

  const GroupMembersScreen({
    super.key,
    required this.memberIds,
    required this.groupName,
  });

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final UserService _userService = ServiceLocator.userService;
  List<User> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _userService.getUsersByIds(widget.memberIds);
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải danh sách thành viên: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7A2FC0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Thành viên (${widget.memberIds.length})',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: Container(
        color: const Color(0xFFF5F5F5),
        child: _isLoading
            ? _buildShimmerList()
            : _members.isEmpty
            ? const Center(child: Text('Không có thành viên'))
            : ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];
                  return _buildMemberItem(member);
                },
              ),
      ),
    );
  }

  Widget _buildMemberItem(User member) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProfileScreen(userId: member.id, hideMessageButton: true),
          ),
        );
      },
      child: Container(
        color: Colors.white,
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage:
                member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null || member.avatarUrl!.isEmpty
                ? Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : '#',
                  )
                : null,
          ),
          title: Text(
            member.displayName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '@${member.username}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: ListTile(
          leading: const CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
          ),
          title: Container(
            height: 14,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
          subtitle: Container(
            height: 14,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
        ),
      ),
    );
  }
}
