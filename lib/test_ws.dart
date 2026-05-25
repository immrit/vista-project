import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// A simple test screen to verify WebSocket connection to the backend.
void main() {
  runApp(const WSTestApp());
}

class WSTestApp extends StatelessWidget {
  const WSTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebSocket Test',
      theme: ThemeData(useMaterial3: true),
      home: const WSTestScreen(),
    );
  }
}

class WSTestScreen extends StatefulWidget {
  const WSTestScreen({super.key});

  @override
  State<WSTestScreen> createState() => _WSTestScreenState();
}

class _WSTestScreenState extends State<WSTestScreen> {
  late WebSocketChannel _channel;
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    // Use your local testing token here or disable auth momentarily
    // Since RequireAuth is enabled, you need to pass an Authorization header,
    // or pass the token via query param: ws://10.0.2.2:8080/ws?token=XYZ
    // For test purposes, we'll assume the URL handles it.
    _connect();
  }

  void _connect() {
    try {
      _channel = WebSocketChannel.connect(
        // Use 10.0.2.2 for Android emulator, or localhost for web/desktop
        Uri.parse('ws://127.0.0.1:8080/ws'),
      );
      setState(() {
        _isConnected = true;
        _messages.add('System: Connecting...');
      });

      _channel.stream.listen((message) {
        setState(() {
          _messages.add('Received: $message');
        });
      }, onError: (error) {
        setState(() {
          _messages.add('Error: $error');
          _isConnected = false;
        });
      }, onDone: () {
        setState(() {
          _messages.add('System: Connection closed');
          _isConnected = false;
        });
      });
    } catch (e) {
      setState(() {
        _messages.add('Exception: $e');
      });
    }
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty && _isConnected) {
      final msg = _controller.text;
      _channel.sink.add(msg);
      setState(() {
        _messages.add('Sent: $msg');
        _controller.clear();
      });
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebSocket Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(_isConnected ? 'Connected' : 'Disconnected'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return Text(_messages[index]);
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration:
                        const InputDecoration(hintText: 'Enter message...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
