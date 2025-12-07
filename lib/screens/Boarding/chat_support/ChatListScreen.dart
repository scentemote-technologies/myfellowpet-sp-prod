import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final _db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text('Incoming Chats', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // newest first:
        stream: _db
            .collection('chats')
            .orderBy('lastUpdated', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(child: Text('No chats yet', style: GoogleFonts.poppins()));
          }
          final docs = snap.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data      = docs[i].data() as Map<String, dynamic>;
              final serviceId = data['serviceId']   as String;
              final lastMsg   = data['lastMessage'] as String? ?? '';
              final ts        = data['lastUpdated'] as Timestamp?;
              final timeStr   = ts != null
                  ? TimeOfDay.fromDateTime(
                  ts.toDate().toLocal()
              ).format(context)
                  : '';

              return ListTile(
                title:    Text('Chat: $serviceId', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  lastMsg,
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  timeStr,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
               /* onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(serviceId: serviceId),
                  ),
                ),*/
              );
            },
          );
        },
      ),
    );
  }
}
