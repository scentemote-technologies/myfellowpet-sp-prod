// imports
import 'dart:html' as html; // for Flutter Web URL parsing
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../Colors/AppColor.dart';


/// This widget contains all of your SPChatPage logic, minus its Scaffold.
/// It manages its own Firestore sessions, streams, bubbles, option taps, etc.
class SpGeneralQueryChatbot extends StatefulWidget {
  final String serviceId;
  final String shop_name;
  final String shop_phone_number;
  final String shop_email;

  const SpGeneralQueryChatbot({
    Key? key,
    required this.serviceId,
    required this.shop_name,
    required this.shop_phone_number,
    required this.shop_email,
  }) : super(key: key);

  @override
  _SpGeneralQueryChatbotState createState() => _SpGeneralQueryChatbotState();
}

class _SpGeneralQueryChatbotState extends State<SpGeneralQueryChatbot> {
  String? _orderId;
  String? _sessionId;
  Map<String, dynamic>? _menu;
  String _currentNode = 'start';
  bool _loading = true, _botTyping = false, _showEscalation = false, _historyMode = false;
  final _scrollCtrl = ScrollController();
  final _answered = <String>{};
  late final String _uid;

  Stream<QuerySnapshot>? _messagesStream;
  List<DocumentSnapshot> _cachedDocs = [];

  List<String>? _orderIds;
  bool _ordersLoading = false;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
    _initSession();
  }

  Future<void> _initSession() async {
    setState(() => _loading = true);

    // 1. Create the session document
    final doc = await FirebaseFirestore.instance
        .collection('SpGeneralQueries')
        .add({
      'participants': [_uid],
      'flowId': 'general_support_sp_v1',
      'createdAt': Timestamp.now(),
      'role': 'web_user',
      'serviceId': widget.serviceId, // <-- You should add this too
      'shop_name': widget.shop_name, // <-- ADD THIS
      'shop_phone_number': widget.shop_phone_number // <-- AND THIS
    });
    _sessionId = doc.id;

    // 2. Load menu config
    final cfg = await FirebaseFirestore.instance
        .collection('menuConfigs')
        .doc('general_support_sp_v1')
        .get();
    _menu = cfg.data()!['nodes'] as Map<String, dynamic>;

    // 3. Wire up the messages stream
    _messagesStream = FirebaseFirestore.instance
        .collection('SpGeneralQueries')
        .doc(_sessionId)
        .collection('messages')
        .orderBy('ts')
        .snapshots();

    // 4. Reset UI state & send initial prompt
    setState(() {
      _loading = false;
      _historyMode = false;
      _answered.clear();
      _showEscalation = false;
      _cachedDocs = [];
    });

    final initialPrompt = 'Hey there! What can we help you with?';

    _sendBot(initialPrompt, _menu![_currentNode]['options'] as List<dynamic>);
  }

  Future<void> _sendBot(String text, List<dynamic> opts) async {
    if (_sessionId == null) return;
    setState(() => _botTyping = true);
    await Future.delayed(const Duration(milliseconds: 400));
    await FirebaseFirestore.instance
        .collection('SpGeneralQueries')
        .doc(_sessionId)
        .collection('messages')
        .add({
      'sender': 'bot',
      'type': 'text',
      'payload': text,
      'options': opts,
      'ts': Timestamp.now(),
    });
    setState(() {
      _botTyping = false;
      _scrollToBottom();
      if (opts.isEmpty) _showEscalation = true;
    });
  }

  void _onTap(Map<String, dynamic> opt, String msgId) {
    if (_sessionId == null || _answered.contains(msgId)) return;
    FirebaseFirestore.instance
        .collection('SpGeneralQueries')
        .doc(_sessionId)
        .collection('messages')
        .add({
      'sender': 'user',
      'type': 'option',
      'payload': opt['label'], // <-- store the label for display
      'rawKey': opt['key'],
      'ts': Timestamp.now(),
    });
    setState(() => _answered.add(msgId));
    _currentNode = opt['key'];
    final next = _menu![_currentNode] as Map<String, dynamic>?;
    if (next != null) _sendBot(next['text'], next['options'] as List<dynamic>);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _bubble(Map<String, dynamic> d, String id) {
    final isBot = d['sender'] == 'bot';
    final txt = d['payload'] as String;
    final ts = (d['ts'] as Timestamp).toDate();
    final opts = isBot
        ? (d['options'] as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    final align = isBot ? Alignment.centerLeft : Alignment.centerRight;
    final bg = isBot ? Colors.white : primaryColor.withOpacity(0.3);
    final radius = BorderRadius.only(
      topLeft: Radius.circular(12),
      topRight: Radius.circular(isBot ? 0 : 12),
      bottomLeft: Radius.circular(isBot ? 12 : 0),
      bottomRight: Radius.circular(12),
    );

    return Align(
      alignment: align,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(
              txt,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.2,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.poppins(
                fontSize: 8,
                color: Colors.grey.shade600,
              ),
            ),
            if (isBot && !_answered.contains(id) && opts.isNotEmpty && !_historyMode)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: opts.map((o) {
                    return GestureDetector(
                      onTap: () => _onTap(o, id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: primaryColor, width: 1.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          o['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF2CB4B6),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              'Chat with us',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _messagesStream,
                    builder: (ctx, snap) {
                      final docs = snap.data?.docs ?? _cachedDocs;
                      if (snap.hasData) _cachedDocs = docs;
                      return ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: docs.length + (_botTyping ? 1 : 0),
                        itemBuilder: (c, i) {
                          if (i < docs.length) {
                            return _bubble(docs[i].data()! as Map<String, dynamic>, docs[i].id);
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Bot is typing…',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SpGeneralQueryChatbotButton extends StatefulWidget {
  final String serviceId;
  final String shop_name;
  final String shop_phone_number;
  final String shop_email;

  const SpGeneralQueryChatbotButton({
    Key? key,
    required this.serviceId,
    required this.shop_name,
    required this.shop_phone_number,
    required this.shop_email,
  }) : super(key: key);

  @override
  _SpGeneralQueryChatbotButtonState createState() =>
      _SpGeneralQueryChatbotButtonState();
}

class _SpGeneralQueryChatbotButtonState
    extends State<SpGeneralQueryChatbotButton> {
  bool _showChat = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;

    final bool isMobile = screenWidth < 600;

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 20,
          right: isMobile ? 12 : 24, // spacing from right
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Chat popup
            if (_showChat)
              Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: isMobile ? screenWidth * 0.9 : 320,
                  height: isMobile ? 380 : 420,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      user != null
                          ? SpGeneralQueryChatbot(
                        serviceId: widget.serviceId,
                        shop_name: widget.shop_name,
                        shop_email: widget.shop_email,
                        shop_phone_number: widget.shop_phone_number,
                      )
                          : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Kindly sign in first to continue',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),

                      // Close button
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => setState(() => _showChat = false),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 20, color: Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Toggle button at bottom-right
            GestureDetector(
              onTap: () => setState(() => _showChat = !_showChat),
              child: FittedBox(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.headset_mic, color: primaryColor, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        'General Enquiries',
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}