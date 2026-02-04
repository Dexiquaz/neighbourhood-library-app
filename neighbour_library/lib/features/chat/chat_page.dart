import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatPage extends StatefulWidget {
  final String requestId;
  final String otherUserId;

  const ChatPage({
    super.key,
    required this.requestId,
    required this.otherUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _client = Supabase.instance.client;
  final _controller = TextEditingController();
  List<dynamic> _messages = [];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _listenRealtime();
  }

  Future<void> _fetchMessages() async {
    final data = await _client
        .from('chat_messages')
        .select()
        .eq('request_id', widget.requestId)
        .order('created_at');

    if (!mounted) return;
    setState(() => _messages = data);
  }

  void _listenRealtime() {
    _client
        .channel('chat-${widget.requestId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'request_id',
            value: widget.requestId,
          ),
          callback: (_) => _fetchMessages(),
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final user = _client.auth.currentUser!;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await _client.from('chat_messages').insert({
      'request_id': widget.requestId,
      'sender_id': user.id,
      'receiver_id': widget.otherUserId,
      'message': text,
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final myId = _client.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                final isMe = msg['sender_id'] == myId;

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg['message']),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
