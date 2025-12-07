import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReadOurStory extends StatelessWidget {
  const ReadOurStory({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar with gradient background, custom back arrow, and centered title.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff6A11CB), Color(0xff2575FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: const Text(
            'Our Story',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Header Section remains static (or you can later make it dynamic)
          const SliverToBoxAdapter(child: HeaderSection()),
          // Timeline Section: Retrieves events from Firestore dynamically.
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('company_documents')
                .doc('read_our_story')
                .collection('timeline_events')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()));
              }
              final docs = snapshot.data!.docs;
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final bool isLeft = index % 2 == 0;
                    final bool isFirst = index == 0;
                    final bool isLast = index == docs.length - 1;
                    return TimelineTile(
                      date: data['date'] ?? '',
                      description: data['description'] ?? '',
                      isLeft: isLeft,
                      isFirst: isFirst,
                      isLast: isLast,
                    );
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

// Responsive Header Section with static background image and text.
class HeaderSection extends StatelessWidget {
  const HeaderSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Adjust header height based on screen width.
    return LayoutBuilder(
      builder: (context, constraints) {
        double headerHeight;
        if (constraints.maxWidth < 600) {
          headerHeight = 300;
        } else if (constraints.maxWidth < 1200) {
          headerHeight = 500;
        } else {
          headerHeight = 700;
        }
        return Container(
          height: headerHeight,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('partnerpage.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            // Overlay gradient for better text readability.
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black54,
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Our Story',
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'From crafting custom scents to pioneering pet solutions, our journey is defined by bold ideas and transformative tech. Discover our milestones and evolution.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// TimelineTile Widget for each event in the timeline.
class TimelineTile extends StatelessWidget {
  final String date;
  final String description;
  final bool isLeft;
  final bool isFirst;
  final bool isLast;

  const TimelineTile({
    Key? key,
    required this.date,
    required this.description,
    required this.isLeft,
    required this.isFirst,
    required this.isLast,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left side card for left-aligned events.
          if (isLeft)
            Expanded(child: _buildCard(context))
          else
            Expanded(child: Container()),
          // Central timeline indicator.
          Container(
            width: 40,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : Colors.grey.shade400,
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF0064E5),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          // Right side card for right-aligned events.
          if (!isLeft)
            Expanded(child: _buildCard(context))
          else
            Expanded(child: Container()),
        ],
      ),
    );
  }

  // Build the card displaying the date and description.
  Widget _buildCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}