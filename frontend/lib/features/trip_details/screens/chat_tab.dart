import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/auth_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class ChatMessage {
  final String id;
  final String type;
  final String userId;
  final String username;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.type,
    required this.userId,
    required this.username,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      type: json['type'] ?? 'chat',
      userId: json['user_id'] ?? '',
      username: json['username'] ?? '',
      text: json['text'] ?? json['message'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

class ChatTab extends ConsumerStatefulWidget {
  final String tripId;
  const ChatTab({super.key, required this.tripId});

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  final List<ChatMessage> _messages = [];
  final _textController = TextEditingController();
  WebSocketChannel? _channel;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    _currentUserId = user.id;

    // Assuming local host for emulator
    final wsUrl = Uri.parse('ws://localhost:8000/ws/trips/${widget.tripId}?user_id=${user.id}&username=${user.username}');
    
    _channel = WebSocketChannel.connect(wsUrl);
    _channel!.stream.listen((data) {
      if (!mounted) return;
      final decodedData = json.decode(data);
      setState(() {
         // We only append chat and system messages to the UI view
         if (decodedData['type'] == 'chat' || decodedData['type'] == 'system') {
           _messages.add(ChatMessage.fromJson(decodedData));
         }
      });
    }, onError: (error) {
      // Handle socket error gracefully
    });
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty || _channel == null) return;
    final text = _textController.text.trim();
    
    _channel!.sink.add(json.encode({
      "type": "chat",
      "text": text,
    }));
    
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
            ? const Center(child: Text('No messages yet. Say hi!'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  
                  if (msg.type == 'system') {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(msg.text, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)),
                      ),
                    );
                  }
                  
                  final isMe = msg.userId == _currentUserId;
                  
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.deepPurple : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(16).copyWith(
                          bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                          bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(16),
                        )
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isMe)
                             Text(msg.username, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.deepPurple.shade900)),
                          Text(
                            msg.text, 
                            style: TextStyle(color: isMe ? Colors.white : Colors.black, fontSize: 16)
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat.Hm().format(msg.timestamp), 
                            style: TextStyle(color: isMe ? Colors.white70 : Colors.black54, fontSize: 10)
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.deepPurple,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}
