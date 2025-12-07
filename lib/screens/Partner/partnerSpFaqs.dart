import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class PartnerFaqPage extends StatefulWidget {

  const PartnerFaqPage({
    Key? key,
  }) : super(key: key);

  @override
  _PartnerFaqPageState createState() => _PartnerFaqPageState();
}

class _PartnerFaqPageState extends State<PartnerFaqPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _searchTerm = '';
  bool _expandAll = false;

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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // 1️⃣ Search bar on the left
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        hintText: 'Search FAQs...',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey),
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // 2️⃣ “Show All” box with outline, black text & switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

                    child: Row(
                      children: [
                        Text(
                          'Show All',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _expandAll,
                          onChanged: (v) => setState(() => _expandAll = v),
                          activeColor: Color(0xFF2CB4B6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),




          // FAQ list
          SliverFillRemaining(
            hasScrollBody: true,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('partner_onboarding_faqs')
                  .orderBy('order')
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error loading FAQs',
                      style: GoogleFonts.poppins(color: Color(0xFF2CB4B6)),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final allDocs = snap.data!.docs;
                final filtered = allDocs.where((d) {
                  final q = (d['question'] as String).toLowerCase();
                  return _searchTerm.isEmpty || q.contains(_searchTerm);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No FAQs found',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final data = filtered[i].data()! as Map<String, dynamic>;

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent, // ← no dividers
                        ),
                        child: ExpansionTile(
                          key: Key('faq-$i-$_expandAll'),
                          initiallyExpanded: _expandAll,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            '${i + 1}. ${data['question'] ?? ''}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                data['answer'] ?? '',
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );

              },
            ),
          ),
        ],
      ),
      /*floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onContactSupport,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        icon: Icon(Icons.headset_mic),
        label: Text(
          'Contact Support',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFF2CB4B6), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),*/
    );
  }
}
