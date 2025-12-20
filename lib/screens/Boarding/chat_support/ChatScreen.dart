// lib/screens/chat/chat_screen_sp.dart

import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'chat_helper.dart';


class ChatScreenSP extends StatefulWidget {
  final String chatId;
  final String bookingId;
  final String serviceId;
  final String shop_name;
  ChatScreenSP({required this.chatId, required this.bookingId, required this.serviceId, required this.shop_name});

  @override
  _ChatScreenSPState createState() => _ChatScreenSPState();
}

class _ChatScreenSPState extends State<ChatScreenSP> {
  final _db        = FirebaseFirestore.instance;
  final _messaging = FirebaseMessaging.instance;
  late final types.User _me;
  List<types.Message> _messages    = [];
  bool _spChatEnabled               = true;

  @override
  void initState() {
    super.initState();
    _me = types.User(id: FirebaseAuth.instance.currentUser!.uid);
    final chatDoc = _db.collection('chats').doc(widget.chatId);

    // Subscribe and mark read
    if (!kIsWeb) {
      _messaging.subscribeToTopic('chat_${widget.chatId}');
    }
    chatDoc.set({
      'lastReadBy_${_me.id}': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Listen for sp_chat toggle
    chatDoc.snapshots().listen((snap) {
      final data = snap.data() as Map<String, dynamic>? ?? {};
      setState(() {
        _spChatEnabled = data['sp_chat'] as bool? ?? true;
      });
    });

    // Live listen to messages
    chatDoc
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .listen((snap) {
      final msgs = snap.docs.map((d) {
        final data = d.data();
        final ts = data['timestamp'];
        final createdAt = ts is Timestamp
            ? ts.millisecondsSinceEpoch
            : DateTime.now().millisecondsSinceEpoch;

        if (data['type'] == 'image') {
          return types.ImageMessage(
            id: d.id,
            author: types.User(id: data['senderId']),
            uri: data['imageUrl'],
            createdAt: createdAt,
            metadata: {'sent_by': data['sent_by']},
            name: 'image',
            size: 0,
          );
        } else {
          return types.TextMessage(
            id: d.id,
            author: types.User(id: data['senderId']),
            text: data['text'],
            createdAt: createdAt,
            metadata: {'sent_by': data['sent_by']},
          );
        }
      }).toList();

      setState(() => _messages = msgs.reversed.toList());

      // Update last-read
      chatDoc.update({
        'lastReadBy_${_me.id}': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with Parent', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          if (!_spChatEnabled)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Your ability to chat has been blocked by admin.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
              ),
            ),
          // ←── ADD THE “POINTS TO REMEMBER” SECTION HERE ──────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Points to Remember',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildBullet('Be respectful to each other'),
                _buildBullet('Do not share personal information'),
                _buildBullet('Keep language clean and professional'),
                _buildBullet('Chats auto-delete 30 days after booking completion'),
                // …add more rules as needed
              ],
            ),
          ),
          Expanded(
            child: Chat(
              messages: _messages,
              user:     _me,
              onSendPressed: (types.PartialText msg) {
                if (!_spChatEnabled) return;
                ChatHelper.sendMessage(
                  context: context,
                  chatId:  widget.chatId,
                  message: msg,
                  sentBy:  'sp', // marks this as service-provider
                );
              },
              onAttachmentPressed: () async {
                if (!_spChatEnabled) return;

                final XFile? image = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                );
                if (image == null) return;

                final tempId = DateTime.now().millisecondsSinceEpoch.toString();
                final now = DateTime.now().millisecondsSinceEpoch;

                String previewUri;

                if (kIsWeb) {
                  final bytes = await image.readAsBytes();
                  previewUri = _bytesToDataUrl(bytes); // 👈 WEB FIX
                } else {
                  previewUri = image.path; // 👈 MOBILE FIX
                }

                // 🔹 Optimistic preview
                setState(() {
                  _messages.insert(
                    0,
                    types.ImageMessage(
                      id: tempId,
                      author: _me,
                      uri: previewUri,
                      createdAt: now,
                      metadata: {'uploading': true, 'sent_by': 'sp'},
                      name: 'uploading',
                      size: 0,
                    ),
                  );
                });

                // 🔹 Upload & persist
                await ChatHelper.sendImageWithFile(
                  context: context,
                  chatId: widget.chatId,
                  sentBy: 'sp',
                  file: image,
                );
              },



              systemMessageBuilder: (types.SystemMessage message) {
                if (message.id != 'rules') return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── LEFT COLUMN: booking/shop info ───────────────────
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order ID: ${widget.bookingId}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Shop: ${widget.shop_name}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── RIGHT COLUMN: Points to Remember ─────────────────
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                              child: Text(
                                'Points to Remember',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),
                            // Bullets
                            Padding(
                              padding: const EdgeInsets.only(left: 24.0, right: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildBullet('Be respectful to each other'),
                                  _buildBullet('Do not share personal information'),
                                  _buildBullet('Keep language clean and professional'),
                                  // …add more rules as needed
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },

              theme: DefaultChatTheme(
                inputBackgroundColor: Colors.grey.shade100,
                inputTextColor: Colors.black,
                inputTextCursorColor: Colors.black,
                inputBorderRadius: BorderRadius.circular(12),
                inputPadding: EdgeInsets.fromLTRB(5, 15, 5, 10),
                inputTextStyle: TextStyle(color: Colors.black, fontSize: 16),
                inputContainerDecoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),

                sendButtonIcon: Icon(
                  Icons.send,
                  color: Colors.black,
                ),
                userAvatarTextStyle: GoogleFonts.poppins(fontSize: 12),
                primaryColor: Colors.black,
                secondaryColor: Colors.black87,
                receivedMessageBodyTextStyle: GoogleFonts.poppins(color: Colors.black87),
                sentMessageBodyTextStyle: GoogleFonts.poppins(color: Colors.black),
              ),
              bubbleBuilder: (child, {required message, required nextMessageInGroup}) {
                if (message is types.TextMessage) {
                  final role = (message.metadata?['sent_by'] ?? '').toString();
                  String label;
                  Color borderColor;

                  // 1. Determine Sender & Style
                  switch (role) {
                    case 'sp':
                      label = 'Service Provider';
                      borderColor = Colors.grey;
                      break;
                    case 'admin':
                      label = 'Admin';
                      borderColor = Colors.red;
                      break;
                    case 'user':
                    default:
                      label = 'Pet Parent';
                      borderColor = const Color(0xFF2CB4B6);
                      break;
                  }

                  // Determine if the message is mine (for alignment)
                  final isMyMessage = message.author.id == FirebaseAuth.instance.currentUser!.uid;

                  // 2. Format Time
                  final timestamp = DateTime.fromMillisecondsSinceEpoch(message.createdAt ?? 0);
                  final timeString = DateFormat('hh:mm a').format(timestamp);

                  return Column(
                    // 3. Align the whole message block (label + bubble)
                    crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // 4. Label (Pet Parent / Service Provider)
                      Padding(
                        padding: EdgeInsets.fromLTRB(isMyMessage ? 8 : 12, 0, isMyMessage ? 12 : 8, 0),
                        child: Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),

                      // 5. Chat Bubble Container
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: borderColor, width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        // Wrap the message content (child) and the time in a Column
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Internal padding
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end, // Align contents inside bubble to the right
                            children: [
                              // 5a. Message Text
                              Align(
                                alignment: Alignment.centerLeft, // Ensures text itself starts left
                                child: child,
                              ),
                              const SizedBox(height: 4),

                              // 5b. Timestamp
                              Text(
                                timeString,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
                    ],
                  );
                }
                return child;
              },
            ),

          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ',
              style: TextStyle(fontSize: 16, height: 1.5)), // bullet
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}



String _bytesToDataUrl(Uint8List bytes) {
  final base64Data = base64Encode(bytes);
  return 'data:image/jpeg;base64,$base64Data';
}
