// lib/utils/chat_helper.dart

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
}