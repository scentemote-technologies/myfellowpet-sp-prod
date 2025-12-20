// lib/utils/chat_helper.dart
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatHelper {
  // 1) Define everything you want to block here:
  static final List<RegExp> _bannedPatterns = [
    // Phone‐number‐length runs (6 or more digits)
    RegExp(r'\b\d{6,}\b'),
    // Strict email addresses (requires at least one “.label” after the @)
    RegExp(r'\b[\w.+-]+@[\w-]+(?:\.[\w-]+)+\b'),
    // URLs
    RegExp(r'https?://\S+'),
    // Any stray “@” left behind
    RegExp(r'@'),
  ];

  /// Returns true if [text] passes all your rules.
  static bool isValid(String text) {
    for (final pat in _bannedPatterns) {
      if (pat.hasMatch(text)) return false;
    }
    return true;
  }

  /// Call this in your ChatScreen's onSendPressed.
  /// It will validate, show a SnackBar if invalid, or else write to Firestore.
  static Future<void> sendMessage({
    required BuildContext context,
    required String chatId,
    required types.PartialText message, required String sentBy,
  }) async {
    final text = message.text.trim();
    if (!isValid(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your message contains disallowed content (phone numbers, emails, URLs). Please rephrase.',
          ),
        ),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);

    // save the message
    await chatDoc.collection('messages').add({
      'text':      text,
      'senderId':  uid,
      'timestamp': FieldValue.serverTimestamp(),
      'sent_by': sentBy
    });

    // update the chat header
    await chatDoc.set({
      'lastMessage': text,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  static final ImagePicker _picker = ImagePicker();

  static Future<void> sendImage({
    required BuildContext context,
    required String chatId,
    required String sentBy,
  }) async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final Uint8List bytes = await file.readAsBytes();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance
        .ref('chat_images/$chatId/$fileName');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final imageUrl = await ref.getDownloadURL();

    final chatDoc =
    FirebaseFirestore.instance.collection('chats').doc(chatId);

// save image message
    await chatDoc.collection('messages').add({
      'type': 'image',
      'imageUrl': imageUrl,
      'senderId': uid,
      'timestamp': FieldValue.serverTimestamp(),
      'sent_by': sentBy,
    });

// update chat header
    await chatDoc.set({
      'lastMessage': '📷 Image',
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<XFile?> pickImage() async {
    return await ImagePicker().pickImage(source: ImageSource.gallery);
  }

  static Future<void> sendImageWithFile({
    required BuildContext context,
    required String chatId,
    required String sentBy,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final ref = FirebaseStorage.instance
        .ref('chat_images/$chatId/${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putData(bytes);
    final imageUrl = await ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'type': 'image',
      'imageUrl': imageUrl,
      'senderId': uid,
      'sent_by': sentBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }


}

