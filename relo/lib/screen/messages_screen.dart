import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:relo/screen/main_screen.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/websocket_service.dart';
import '../services/message_service.dart';

class MessagesScreen extends StatefulWidget {
  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final MessageService messageService = ServiceLocator.messageService;
  final SecureStorageService _secureStorage = const SecureStorageService();
  StreamSubscription? _webSocketSubscription;
  String? _currentUserId;

  bool _isLoading = true;
  List<dynamic> conversations = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await fetchConversations();
    await _getCurrentUserId();
    _listenToWebSocket();
  }

  Future<void> _getCurrentUserId() async {
    _currentUserId = await _secureStorage.getUserId();
    setState(() {});
  }

  void _listenToWebSocket() {
    _webSocketSubscription = webSocketService.stream.listen((message) {
      final data = jsonDecode(message);

      // Assuming the server sends an event type
      if (data['event'] == 'new_message') {
        // A new message has arrived, refresh the conversation list
        // A more optimized approach would be to update the specific conversation
        fetchConversations();
      }
    }, onError: (error) {
      print("WebSocket Error: $error");
    });
  }

  @override
  void dispose() {
    _webSocketSubscription?.cancel();
    super.dispose();
  }

  Future<void> fetchConversations() async {
    try {
      final fetchedConversations = await messageService.fetchConversations();
      if (mounted) {
        setState(() {
          conversations = fetchedConversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print(e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : conversations.isEmpty
            ? _buildEmptyState()
            : _buildConversationList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_outlined, size: 80, color: Colors.grey[400]),
          SizedBox(height: 20),
          Text(
            'Bạn chưa có cuộc trò chuyện nào',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Hãy thử tìm vài người bạn để trò chuyện nhé'),
            onPressed: () {
              // Find the MainScreenState and call the method to change the tab
              context.findAncestorStateOfType<MainScreenState>()?.changeTab(2);
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Color(0xFF7A2FC0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final participantIds = List<String>.from(
          conversation['participantIds'] ?? [],
        );

        // Find the other participant's ID
        final otherParticipant = participantIds.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => "Unknown",
        );

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColorLight,
            child: Text(
              otherParticipant.isNotEmpty
                  ? otherParticipant[0].toUpperCase()
                  : '?',
              style: TextStyle(color: Theme.of(context).primaryColorDark),
            ),
          ),
          title: Text(
            'Conversation with $otherParticipant',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            conversation['lastMessage']?['content'] ?? 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: conversation['updatedAt'] != null
              ? Text(
                  conversation['updatedAt'].toString().substring(11, 16),
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                )
              : null,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tapping on conversation ${conversation['id']}'),
              ),
            );
          },
        );
      },
    );
  }
}
