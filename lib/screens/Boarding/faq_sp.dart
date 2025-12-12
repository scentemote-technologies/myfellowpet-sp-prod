import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'SPChatWidget.dart';

class SpFaqPage extends StatefulWidget {
  final String serviceId;
  final VoidCallback onContactSupport;

  const SpFaqPage({
    Key? key,
    required this.serviceId,
    required this.onContactSupport,
  }) : super(key: key);

  @override
  _SpFaqPageState createState() => _SpFaqPageState();
}

class _SpFaqPageState extends State<SpFaqPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  bool _expandAll = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchTerm = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildSearchBarAndToggle(),
          _buildFaqStream(),
        ],
      ),
      floatingActionButton: _buildContactSupportButton(),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 0.0,
      backgroundColor: kPrimary,
      pinned: true,
      automaticallyImplyLeading: false, // 🚀 removes the back arrow
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Help & Support',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16),
      ),
    );
  }


  SliverToBoxAdapter _buildSearchBarAndToggle() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Row(
          children: [
            // Search Bar
            Expanded(
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  hintText: 'Search FAQs...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Expand All',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: _expandAll,
              onChanged: (v) => setState(() => _expandAll = v),
              activeColor: kPrimary,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFaqStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('faqs_sp').orderBy('order').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _buildNoResults('Error loading FAQs');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoResults('No FAQs available.');
        }

        final allDocs = snapshot.data!.docs;
        final filteredFaqs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final question = (data['question'] as String? ?? '').toLowerCase();
          return _searchTerm.isEmpty || question.contains(_searchTerm);
        }).toList();

        if (filteredFaqs.isEmpty) {
          return _buildNoResults("No results for '$_searchTerm'");
        }

        return _buildFaqList(filteredFaqs);
      },
    );
  }

  SliverList _buildFaqList(List<QueryDocumentSnapshot> faqs) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final faqData = faqs[index].data()! as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Card(
              color: Colors.white,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey('${faqs[index].id}-$_expandAll'),
                  initiallyExpanded: _expandAll,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Align(
                    alignment: Alignment.centerLeft, // ✅ Ensures left alignment
                    child: Text(
                      faqData['question'] ?? '',
                      textAlign: TextAlign.start, // ✅ Text alignment
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Align(
                        alignment: Alignment.centerLeft, // ✅ Force answer to left
                        child: Text(
                          faqData['answer'] ?? '',
                          textAlign: TextAlign.start, // ✅ Answer text left aligned
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

            },
        childCount: faqs.length,
      ),
    );
  }

  SliverFillRemaining _buildNoResults(String message) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  FloatingActionButton _buildContactSupportButton() {
    return FloatingActionButton.extended(
      onPressed: widget.onContactSupport,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      icon: const FaIcon(FontAwesomeIcons.headset),
      label: Text(
        'Contact Support',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: kPrimary, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}