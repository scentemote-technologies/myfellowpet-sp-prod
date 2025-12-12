// lib/sp_main.dart
import 'dart:html' as html; // for Flutter Web URL parsing
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../Widgets/reusable_splash_screen.dart';
import '../../Partner/email_signin.dart';
import 'SpGeneralQueryChatbot.dart';

enum SearchMode { orderId, name, number }

// Add this state variable
SearchMode _currentSearchMode = SearchMode.orderId;


class SPChatPage extends StatefulWidget {
  final String? initialOrderId;
  final String serviceId;
  final String shop_name;
  final String shop_phone_number;
  final String shop_email;
  final String? drawerType; // <-- ADDED: Parameter to track the last-opened drawer

  const SPChatPage({
    Key? key,
    required this.initialOrderId,
    required this.serviceId,
    required this.shop_name,
    required this.shop_phone_number,
    required this.shop_email,
    this.drawerType, // <-- ADDED: Parameter to track the last-opened drawer
  }) : super(key: key);

  @override
  _SPChatPageState createState() => _SPChatPageState();
}

class _SPChatPageState extends State<SPChatPage> {


  String? _orderId;
  String? _sessionId;
  final String myCurrentServiceId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Map<String, dynamic>? _menu;
  String _currentNode = 'start';
  bool _loading = true,
      _botTyping = false,
      _showEscalation = false,
      _historyMode = false;
  final _scrollCtrl = ScrollController();
  final _answered = <String>{};
  late final String _uid;

  // ADD THESE NEW VARIABLES to the _SPChatPageState class:
  final _searchQueryController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  String? _searchErrorText;

  Stream<QuerySnapshot>? _messagesStream;
  List<DocumentSnapshot> _cachedDocs = [];

  List<String>? _orderIds;
  bool _ordersLoading = false;

  bool _isManualEntryMode = false;
  final _manualOrderIdController = TextEditingController();
  String? _manualOrderErrorText;

  // ▼▼▼ ADD THESE NEW VARIABLES FOR RESPONSIVE UI ▼▼▼
  static const double _mobileBreakpoint = 800.0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Widget? _drawerContent;
  // ▲▲▲ END OF NEW VARIABLES ▲▲▲

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
    _loadCompletedOrders();

    if (widget.initialOrderId != null) {
      _loadAndDisplaySession(widget.initialOrderId!);
    }
  }

  @override
  void didUpdateWidget(covariant SPChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOrderId != oldWidget.initialOrderId) {
      if (widget.initialOrderId != null) {
        _loadAndDisplaySession(widget.initialOrderId!);
      } else {
        setState(() {
          _sessionId = null;
          _orderId = null;
          _messagesStream = null;
          _cachedDocs = [];
          _historyMode = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _manualOrderIdController.dispose();
    super.dispose();
  }

  Future<void> _loadAndDisplaySession(String ticketId) async {
    setState(() => _loading = true);
    _sessionId = ticketId;
    _currentNode = 'start';

    try {
      final sessionDoc = await FirebaseFirestore.instance
          .collection('chatSessions')
          .doc(ticketId)
          .get();
      if (sessionDoc.exists) {
        _orderId = sessionDoc.data()?['orderId'];
      }

      final cfg = await FirebaseFirestore.instance
          .collection('menuConfigs')
          .doc('support_sp_v1')
          .get();
      _menu = cfg.data()!['nodes'] as Map<String, dynamic>;

      _messagesStream = FirebaseFirestore.instance
          .collection('chatSessions')
          .doc(ticketId)
          .collection('messages')
          .orderBy('ts')
          .snapshots();

      final messagesSnap = await FirebaseFirestore.instance
          .collection('chatSessions')
          .doc(ticketId)
          .collection('messages')
          .limit(1)
          .get();

      if (messagesSnap.docs.isEmpty) {
        final initialPrompt = (_orderId == null)
            ? 'What can we help you with?'
            : 'How can I help with Order $_orderId?';
        _sendBot(
          initialPrompt,
          _menu![_currentNode]['options'] as List<dynamic>,
        );
      }

      setState(() {
        _loading = false;
        _historyMode = true;
      });
    } catch (e) {
      print("Error loading session: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _loadCompletedOrders() async {
    setState(() => _ordersLoading = true);
    try {
      final completedSnap = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .collection('completed_orders')
          .get();
      final completedIds = completedSnap.docs.map((d) => d.id).toList();

      final bookingSnap = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .collection('service_request_boarding')
          .get();
      final bookingIds = bookingSnap.docs.map((d) => d.id).toList();

      setState(() {
        _orderIds = [...completedIds, ...bookingIds];
        _ordersLoading = false;
      });
    } catch (e) {
      print('❌ Error loading orders: $e');
      setState(() => _ordersLoading = false);
    }
  }

  Future<void> _sendBot(String text, List<dynamic> opts) async {
    if (_sessionId == null) return;
    setState(() => _botTyping = true);
    await Future.delayed(const Duration(milliseconds: 400));
    await FirebaseFirestore.instance
        .collection('chatSessions')
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
        .collection('chatSessions')
        .doc(_sessionId)
        .collection('messages')
        .add({
      'sender': 'user',
      'type': 'option',
      'payload': opt['label'],
      'rawKey': opt['key'],
      'ts': Timestamp.now(),
    });
    setState(() => _answered.add(msgId));

    _currentNode = opt['key'];
    final next = _menu![_currentNode] as Map<String, dynamic>?;
    if (next != null) {
      _sendBot(next['text'], next['options'] as List<dynamic>);
    }
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
    final bg = isBot ? Colors.white : const Color(0xFF2CB4B6).withOpacity(0.5);
    final radius = isBot
        ? const BorderRadius.only(
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    )
        : const BorderRadius.only(
      topLeft: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );

    return Align(
      alignment: align,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
        ),
        child: Column(
          // Set crossAxisAlignment to end for both to align the timestamp uniformly to the right
          // The overall message alignment is controlled by the outer Align widget.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 1. Message Text (Aligned based on the isBot state)
            Align(
              alignment: isBot ? Alignment.centerLeft : Alignment.centerLeft,
              child: Text(
                txt,
                style: GoogleFonts.poppins(fontSize: 16, height: 1.3),
              ),
            ),
            const SizedBox(height: 6),

            // 2. Timestamp (Aligned to the right of the bubble)
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 2, left: 2),
              child: Text(
                // 💡 TWEAK: Use DateFormat for proper 12-hour format
                DateFormat('hh:mm a').format(ts),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.black54, // Subdued color for visibility
                ),
              ),
            ),

            // 3. Bot Options (Only for bot messages)
            if (isBot && !_answered.contains(id) && opts.isNotEmpty) ...[
              const Divider(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: opts.map((o) {
                  return GestureDetector(
                    onTap: () => _onTap(o, id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF2CB4B6)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Tooltip(
                        message: o['key'] as String,
                        child: Text(
                          o['label'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ▼▼▼ THIS IS THE NEW MAIN BUILD METHOD ▼▼▼
  // It checks the screen width and calls the appropriate layout builder.
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < _mobileBreakpoint;
    if (isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  // ▼▼▼ NEW METHOD FOR THE MOBILE LAYOUT ▼▼▼
  // ▼▼▼ NEW METHOD FOR THE MOBILE LAYOUT ▼▼▼
  // ▼▼▼ NEW METHOD FOR THE MOBILE LAYOUT ▼▼▼
  Widget _buildMobileLayout() {
    // When no chat is selected, show the chat creation form
    if (_sessionId == null) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          automaticallyImplyLeading: false, // <-- Hides the automatic back arrow
          elevation: 1,
          backgroundColor: Colors.white,
          centerTitle: true,
          // ▼▼▼ UPDATED BUTTONS START HERE ▼▼▼
          actions: [
           /* ElevatedButton(
              onPressed: () {
                setState(() => _drawerContent = _buildLiveSessionsList());
                _scaffoldKey.currentState?.openEndDrawer();
              },
              // Apply the new style here
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // White background
                side: const BorderSide(color: Color(0xFF2CB4B6), width: 2), // Blue border
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Live Sessions',
                style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),*/
            ElevatedButton(
              onPressed: () {
                setState(() => _drawerContent = _buildTicketsList());
                _scaffoldKey.currentState?.openEndDrawer();
              },
              // Apply the new style here
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // White background
                side: const BorderSide(color: Color(0xFF2CB4B6), width: 2), // Blue border
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'My Tickets',
                style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // ▼▼▼ UPDATED BUTTONS END HERE ▼▼▼
        ),
        endDrawer: Drawer(child: _drawerContent),
        body: _buildChatSelectionUI(), // Uses a refactored widget
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Theme(
          data: Theme.of(context).copyWith(
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              extendedPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(),
            ),
          ),
          child: Container(
            margin: EdgeInsets.zero,
            child: SpGeneralQueryChatbotButton(
                serviceId: myCurrentServiceId,
                shop_name: widget.shop_name,
                shop_email: widget.shop_email,
                shop_phone_number: widget.shop_phone_number),
          ),
        ),
      );
    }

    // Show a loader while session data is loading
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // When a chat is selected, show the chat messages
    // ... inside _buildMobileLayout()

// When a chat is selected, show the chat messages
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Prevents the default back arrow
        elevation: 1,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          _historyMode ? 'Chat History' : 'Live Chat',
          style: GoogleFonts.poppins(color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _ChatPageLoader(
              serviceId: widget.serviceId,
              ticketId: null, // No ticket on this route
            );
          },
        ),
      ),
      endDrawer: Drawer(child: _buildTicketsList()),
      body: _buildChatStreamUI(),
    );
  }

  // ▼▼▼ NEW METHOD FOR THE DESKTOP LAYOUT (YOUR ORIGINAL BUILD METHOD) ▼▼▼
  Widget _buildDesktopLayout() {
    final orderOptions = <String>[
      if (_orderIds != null) ..._orderIds!,
    ];

    // Calculate dynamic flex factors based on screen width.
    final double screenWidth = MediaQuery.of(context).size.width;
    final int chatFlex = screenWidth > 1200 ? 3 : 2;
    const int ticketsFlex = 2;

    // The desktop layout part where _sessionId == null
    if (_sessionId == null) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: chatFlex,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align search content left
                  children: [
                    // --- Mode Selector (Toggle Buttons) ---
                    ToggleButtons(
                      isSelected: SearchMode.values.map((mode) => mode == _currentSearchMode).toList(),
                      onPressed: (index) {
                        setState(() {
                          _currentSearchMode = SearchMode.values[index];
                          _searchErrorText = null; // Clear previous error
                          _searchQueryController.clear();
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      selectedColor: Colors.white,
                      fillColor: const Color(0xFF2CB4B6),
                      color: const Color(0xFF2CB4B6),
                      constraints: const BoxConstraints(minHeight: 40.0),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text('Order ID', style: GoogleFonts.poppins()),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text('Name', style: GoogleFonts.poppins()),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text('10-Digit Number', style: GoogleFonts.poppins()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- Search Input Field ---
                    TextFormField(
                      controller: _searchQueryController,
                      keyboardType: _currentSearchMode == SearchMode.number ? TextInputType.number : TextInputType.text,
                      maxLength: _currentSearchMode == SearchMode.number ? 10 : null,
                      decoration: InputDecoration(
                        labelText: _currentSearchMode == SearchMode.orderId ? 'Enter Order ID' :
                        _currentSearchMode == SearchMode.name ? 'Enter Owner Name' :
                        'Enter 10-Digit Phone Number',
                        border: const OutlineInputBorder(),
                        errorText: _searchErrorText,
                        suffixIcon: _isSearching
                            ? const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                            : const Icon(Icons.search, color: Color(0xFF2CB4B6)),
                      ),
                      onFieldSubmitted: (_) => _searchOrders(),
                    ),
                    const SizedBox(height: 16),

                    // --- 2. FIND ORDERS BUTTON ---
                    OutlinedButton(
                      onPressed: _isSearching ? null : _searchOrders,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF2CB4B6), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        _isSearching ? 'Searching...' : 'Find Orders',
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 3. SEARCH RESULTS LIST (REPLACES DROPDOWN & INFO) ---
                    if (_isSearching)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)))
                    else if (_searchResults.isNotEmpty)
                      Text('Found ${_searchResults.length} matching orders:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),

                    const SizedBox(height: 8),

                    Expanded(
                      // The search results list should use the remaining space
                      child: (_searchResults.isEmpty && _searchErrorText == null)
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Start a Chat:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 10),
                          ...[
                            "Search for an order using the Order ID, Customer Name, or Phone Number above.",
                            "Chat support is limited to active and completed orders only.",
                            "For general queries, you may use the General Query chatbot (bottom right).",
                          ].map(
                                (txt) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(txt, style: GoogleFonts.poppins(fontSize: 13))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                          : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final doc = _searchResults[index];
                          final data = doc.data() as Map<String, dynamic>;

                          // Assuming 'user_name' and 'phone_number' are present
                          final name = data['user_name_lowercase'] as String? ?? 'Name N/A';
                          final phone = data['phone_number'] as String? ?? 'Phone N/A';
                          final orderId = doc.id;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                              subtitle: Text('$orderId | $phone', style: GoogleFonts.poppins(color: Colors.black54)),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => _ChatPageLoader(
                                      serviceId: widget.serviceId,
                                      ticketId: orderId, // Assuming tid is the $orderId or a similar unique ID
                                    ),
                                  ),
                                );                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              const VerticalDivider(
                width: 1,
                color: Color(0xFF2CB4B6),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: ticketsFlex,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTicketsList()),
                  ],
                ),
              ),
            ],
          ),
        ),
        // FloatingActionButton remains the same
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Theme(
          data: Theme.of(context).copyWith(
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              extendedPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(),
            ),
          ),
          child: Container(
            margin: EdgeInsets.zero,
            child: SpGeneralQueryChatbotButton(
                serviceId: myCurrentServiceId,
                shop_name: widget.shop_name,
                shop_email: widget.shop_email,
                shop_phone_number: widget.shop_phone_number),
          ),
        ),
      );
    }

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text('Support Chat',
            style: GoogleFonts.poppins(color: Colors.black87)),
      ),
      body: Row(
        children: [
          Expanded(
            flex: chatFlex,
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: StreamBuilder<QuerySnapshot>(
                    key: ValueKey(_sessionId),
                    stream: _messagesStream,
                    builder: (ctx, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Text('Error: ${snap.error}',
                              style: GoogleFonts.poppins(color: Colors.red)),
                        );
                      }
                      final docs = snap.data?.docs ?? _cachedDocs;
                      if (snap.hasData) _cachedDocs = docs;
                      return ListView.builder(
                        controller: _scrollCtrl,
                        padding: EdgeInsets.only(top: 12, bottom: _showEscalation ? 60 : 12),
                        itemCount: docs.length + (_botTyping ? 1 : 0),
                        itemBuilder: (c, i) {
                          if (i < docs.length) {
                            return _bubble(docs[i].data()! as Map<String, dynamic>, docs[i].id);
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: Row(
                              children: [
                                const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(width: 8),
                                Text('Bot is typing…',
                                    style: GoogleFonts.poppins(color: Colors.grey)),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
             /*   Expanded(
                  flex: 1, // Give the list its own expanded widget
                  child: _buildLiveSessionsList(),
                ),*/
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          const SizedBox(width: 10),
          Expanded(
            flex: ticketsFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Expanded(child: _buildTicketsList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ▼▼▼ NEW WIDGET FOR THE CHAT SELECTION UI (FOR MOBILE) ▼▼▼
  // ▼▼▼ UPDATED WIDGET FOR RESPONSIVE CHAT SELECTION UI ▼▼▼
  // ▼▼▼ UPDATED WIDGET FOR MOBILE CHAT SELECTION UI (Search Mode) ▼▼▼
  // ... (rest of the file content above _buildChatSelectionUI)

  // ▼▼▼ UPDATED WIDGET FOR MOBILE CHAT SELECTION UI (Search Mode) ▼▼▼
  Widget _buildChatSelectionUI() {
    // We no longer need _orderOptions, _orderIds, _isManualEntryMode, or _ordersLoading
    // in this UI as we are now using the search variables.

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. MODE SELECTOR (Toggle Buttons) ---
            FittedBox(
              fit: BoxFit.scaleDown,
              child: ToggleButtons(
                isSelected: SearchMode.values.map((mode) => mode == _currentSearchMode).toList(),
                onPressed: (index) {
                  setState(() {
                    // **CRITICAL FIX:** Access the global state variable here
                    _currentSearchMode = SearchMode.values[index];
                    _searchErrorText = null;
                    _searchQueryController.clear();
                  });
                },
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: const Color(0xFF2CB4B6),
                color: const Color(0xFF2CB4B6),
                constraints: const BoxConstraints(minHeight: 40.0),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Text('Order ID', style: GoogleFonts.poppins()),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Text('Name', style: GoogleFonts.poppins()),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Text('10-Digit Number', style: GoogleFonts.poppins()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- 2. SEARCH INPUT FIELD (Dynamically adapted) ---
            TextFormField(
              controller: _searchQueryController,
              // Apply keyboard type and max length based on selected mode
              keyboardType: _currentSearchMode == SearchMode.number ? TextInputType.number : TextInputType.text,
              maxLength: _currentSearchMode == SearchMode.number ? 10 : null,
              decoration: InputDecoration(
                labelText: _currentSearchMode == SearchMode.orderId
                    ? 'Enter Order ID'
                    : (_currentSearchMode == SearchMode.name
                    ? 'Enter Owner Name'
                    : 'Enter 10-Digit Phone Number'),
                hintText: _currentSearchMode == SearchMode.orderId
                    ? ''
                    : (_currentSearchMode == SearchMode.name
                    ? ''
                    : ''),
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF2CB4B6), width: 2),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF2CB4B6), width: 2),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF2CB4B6), width: 2),
                ),
                errorText: _searchErrorText,
                suffixIcon: _isSearching
                    ? const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFF2CB4B6)),
                  onPressed: _isSearching ? null : _searchOrders,
                ),
              ),
              onFieldSubmitted: (_) => _searchOrders(),
            ),
            const SizedBox(height: 16),

            // --- 3. FIND ORDERS BUTTON ---
            OutlinedButton(
              onPressed: _isSearching ? null : _searchOrders,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF2CB4B6), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                _isSearching ? 'Searching...' : 'Find Orders',
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- 4. SEARCH RESULTS LIST ---
            if (_isSearching)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_searchResults.isNotEmpty) ...[
              Text('Found ${_searchResults.length} matching orders:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final doc = _searchResults[index];
                  final data = doc.data() as Map<String, dynamic>;

                  // The subtitle now shows the Order ID and Phone Number
                  final name = (data['user_name_lowercase'] as String? ?? 'Name N/A');
                  final phone = data['phone_number'] as String? ?? 'Phone N/A';
                  final orderId = doc.id;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text('$orderId | $phone', style: GoogleFonts.poppins(color: Colors.black54)),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        _ChatPageLoader(
                          serviceId: widget.serviceId,
                          ticketId: null, // No ticket on this route
                        );                      },
                    ),
                  );
                },
              ),
            ] else if (_searchErrorText != null)
              Center(
                child: Text(
                  _searchErrorText!,
                  style: GoogleFonts.poppins(color: Colors.red, fontSize: 16),
                ),
              )
            else ...[
                // Default information when no search has been performed
                Text('Start a Chat:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                ...[
                  "Select the search type above (Order ID, Name, or 10-Digit Number).",
                  "Chat support is limited to active and completed orders only.",
                  "If the order is not found, please Request a Callback.",
                ].map(
                      (txt) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(child: Text(txt, style: GoogleFonts.poppins(fontSize: 13))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Button to Request a Callback
                OutlinedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Confirm Callback', style: GoogleFonts.poppins()),
                        content: Text('Are you sure you want to request a callback?', style: GoogleFonts.poppins()),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('No', style: GoogleFonts.poppins())),
                          TextButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('chatSessions').add({
                                'participants': [_uid],
                                'flowId': 'support_sp_v1',
                                'orderId': null,
                                'createdAt': Timestamp.now(),
                                'serviceId': widget.serviceId,
                                'role': 'sp',
                                'type': 'callback',
                                'mark_as_closed': false,
                                'shop_name': widget.shop_name, // <-- ADD THIS LINE
                                'shop_phone_number': widget.shop_phone_number
                              });
                              if (mounted) Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Callback requested – Admin will reach out soon.', style: GoogleFonts.poppins())),
                              );
                            },
                            child: Text('Yes', style: GoogleFonts.poppins()),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.orange, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: Text(
                    'Request a Callback',
                    style: GoogleFonts.poppins(color: Colors.orange, fontWeight: FontWeight.w500, fontSize: 16),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _searchOrders() async {
    final rawQuery = _searchQueryController.text.trim();
    final serviceId = widget.serviceId;

    // --- 1. Initial Validation & Cleanup ---
    if (rawQuery.isEmpty) {
      setState(() => _searchErrorText = 'Please enter a value to search.');
      return;
    }

    if (_currentSearchMode == SearchMode.number) {
      if (!RegExp(r'^\d{10}$').hasMatch(rawQuery)) {
        setState(() => _searchErrorText = 'Phone number must be exactly 10 digits.');
        return;
      }
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
      _searchErrorText = null;
    });

    try {
      final collectionRef = FirebaseFirestore.instance.collection('users-sp-boarding').doc(serviceId);
      final foundDocs = <DocumentSnapshot>[];
      final searchCollections = ['service_request_boarding', 'completed_orders'];

      // --- 2. Normalized Query Values ---
      final lowerCaseQuery = rawQuery.toLowerCase();
      final prefixEnd = '\u{f8ff}';

      // Final, standardized query value for phone search
      String phoneQueryValue = (_currentSearchMode == SearchMode.number) ? ('+91' + rawQuery) : '';

      print('-------------------------------------------');
      print('🔍 STARTING SEARCH for Service ID: $serviceId');
      print('   > Mode: ${_currentSearchMode.toString().split('.').last}');
      print('   > Raw Input: "$rawQuery"');

      // --- 3. Execute Search ---
      for (final collectionName in searchCollections) {
        final col = collectionRef.collection(collectionName);
        print('   -> Searching collection: $collectionName');

        if (_currentSearchMode == SearchMode.orderId) {
          // ORDER ID SEARCH: Uses the dedicated lowercase field
          final fieldName = 'order_id_lowercase';
          print('      Running Order ID Query (Field: $fieldName): $lowerCaseQuery to ${lowerCaseQuery + prefixEnd}');

          final idSnap = await col
              .where(fieldName, isGreaterThanOrEqualTo: lowerCaseQuery)
              .where(fieldName, isLessThanOrEqualTo: lowerCaseQuery + prefixEnd)
              .limit(10)
              .get();
          foundDocs.addAll(idSnap.docs);
          print('         Found ${idSnap.docs.length} docs via $fieldName.');


        } else if (_currentSearchMode == SearchMode.name) {
          // NAME SEARCH: Uses the dedicated lowercase field
          final fieldName = 'user_name_lowercase';
          print('      Running Name Query (Field: $fieldName): $lowerCaseQuery to ${lowerCaseQuery + prefixEnd}');

          final nameSnap = await col
              .where(fieldName, isGreaterThanOrEqualTo: lowerCaseQuery)
              .where(fieldName, isLessThanOrEqualTo: lowerCaseQuery + prefixEnd)
              .limit(10)
              .get();
          foundDocs.addAll(nameSnap.docs);
          print('         Found ${nameSnap.docs.length} docs via $fieldName.');


        } else if (_currentSearchMode == SearchMode.number) {
          // Phone Search (Exact Prefix Match)
          final fieldName = 'phone_number';
          print('      Running Phone Query (Field: $fieldName): $phoneQueryValue to ${phoneQueryValue + prefixEnd}');

          final phoneSnap = await col
              .where(fieldName, isGreaterThanOrEqualTo: phoneQueryValue)
              .where(fieldName, isLessThanOrEqualTo: phoneQueryValue + prefixEnd)
              .limit(10)
              .get();
          foundDocs.addAll(phoneSnap.docs);
          print('         Found ${phoneSnap.docs.length} docs via $fieldName.');
        }
      }

      // --- 4. Remove Duplicates and Finalize ---
      // Uses document ID as the key to ensure uniqueness
      final uniqueDocsMap = Map<String, DocumentSnapshot>.fromIterable(
          foundDocs.where((doc) => doc.exists),
          key: (doc) => (doc as DocumentSnapshot).id
      );

      final uniqueDocs = uniqueDocsMap.values.toList().cast<DocumentSnapshot>();

      setState(() {
        _searchResults = uniqueDocs;
        _searchErrorText = uniqueDocs.isEmpty ? 'No matching orders found.' : null;
        _isSearching = false;
      });

      print('-------------------------------------------');
      print('✅ SEARCH COMPLETE. Total unique documents found: ${uniqueDocs.length}');
      print('-------------------------------------------');

    } catch (e) {
      print('🚨 CRITICAL FIREBASE ERROR: $e');
      setState(() {
        _searchErrorText = 'A critical error occurred. Please check console for required index links.';
        _isSearching = false;
      });
    }
  }

  // ▼▼▼ NEW WIDGET FOR THE CHAT MESSAGE STREAM (FOR MOBILE) ▼▼▼
  Widget _buildChatStreamUI() {
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey(_sessionId),
      stream: _messagesStream,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('Error: ${snap.error}',
                style: GoogleFonts.poppins(color: Colors.red)),
          );
        }
        final docs = snap.data?.docs ?? _cachedDocs;
        if (snap.hasData) _cachedDocs = docs;
        return ListView.builder(
          controller: _scrollCtrl,
          padding: EdgeInsets.only(top: 12, bottom: _showEscalation ? 60 : 12),
          itemCount: docs.length + (_botTyping ? 1 : 0),
          itemBuilder: (c, i) {
            if (i < docs.length) {
              return _bubble(
                  docs[i].data()! as Map<String, dynamic>, docs[i].id);
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text('Bot is typing…',
                      style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTicketsList({bool isInTab = false}) {
    print("🎬 Starting _buildTicketsList for user $_uid");
    final query = FirebaseFirestore.instance
        .collection('chatSessions')
        .where('participants', arrayContains: _uid)
        .where('serviceId', isEqualTo: widget.serviceId) // Filters by the current service
        .orderBy('createdAt', descending: true)
        .snapshots();

    print("📡 Firestore query built:");
    print("   → Collection: chatSessions");
    print("   → Filter: participants array contains $_uid");
    print("   → Order: createdAt descending");

    return StreamBuilder<QuerySnapshot>(
      stream: query,
      builder: (ctx, snap) {
        if (snap.hasError) { // <--- THIS IS THE KEY CHECK
          // Print the full error object to the console
          print("🚨 Firestore Query Error: ${snap.error}");
        }
        if (snap.connectionState == ConnectionState.waiting) {
          print("⏳ Waiting for Firestore to return documents...");
          return const Center(child: CircularProgressIndicator());
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No tickets found",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }
        final docs = snap.data!.docs;
        print("📥 Firestore snapshot received with ${docs.length} documents");

        // Log each document story
        for (var d in docs) {
          final data = d.data() as Map<String, dynamic>;
          print("────────────────────────────");
          print("📄 Ticket doc ID: ${d.id}");
          print("   → Participants: ${data['participants']}");
          print("   → Type: ${data['type']}");
          print("   → Closed?: ${data['mark_as_closed'] ?? false}");
          print("   → CreatedAt: ${data['createdAt']}");
          if (data.containsKey('service_id')) {
            print("   → ServiceId: ${data['service_id']}");
          }
        }
        print("────────────────────────────");

        final screenWidth = MediaQuery.of(ctx).size.width;
        final isMobile = screenWidth < 600;

        final double titleFontSize =
        (isInTab ? (isMobile ? 14 : 16) : (isMobile ? 12 : 14)).toDouble();
        final double subtitleFontSize =
        (isInTab ? (isMobile ? 12 : 14) : (isMobile ? 10 : 12)).toDouble();
        final double iconSize =
        (isInTab ? (isMobile ? 24 : 28) : (isMobile ? 20 : 24)).toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // My Tickets Heading
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Text(
                'My Tickets',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),

            if (docs.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No tickets found.',
                    style: GoogleFonts.poppins(
                        fontSize: isInTab ? 14.0 : 16.0, color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: isMobile ? 8.0 : 16.0),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final data = doc.data()! as Map<String, dynamic>;
                    final isCallback = data['type'] == 'callback';
                    final isClosed = data['mark_as_closed'] ?? false;
                    final createdAt = (data['createdAt'] as Timestamp).toDate();
                    final createdAtStr =
                    DateFormat('hh:mm a, MMM d, yyyy').format(createdAt);
                    final isSelected = doc.id == _sessionId;

                    print("🎟 Building UI for Ticket ${doc.id}");
                    print("   → Callback? $isCallback");
                    print("   → Closed? $isClosed");
                    print("   → Selected? $isSelected");
                    print("   → CreatedAt: $createdAtStr");

                    return FutureBuilder<String?>(
                      future: _getPayloadIfSecondIsPlusOne(doc.id),
                      builder: (context, async) {
                        final payloadText = async.data;

                        if (payloadText != null && payloadText.isNotEmpty) {
                          print("   → Payload found for ${doc.id}: $payloadText");
                        } else {
                          print("   → No payload found for ${doc.id}");
                        }

                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 2.0),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2CB4B6).withOpacity(0.2)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10.0),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 2.0,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: isInTab ? 10.0 : 6.0,
                                    horizontal: isMobile ? 12.0 : 16.0),
                                leading: Icon(
                                  isCallback
                                      ? Icons.call
                                      : (isClosed ? Icons.lock : Icons.chat),
                                  color: isCallback
                                      ? Colors.orangeAccent
                                      : (isClosed ? Colors.grey : Colors.teal),
                                  size: iconSize,
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (payloadText != null &&
                                        payloadText.isNotEmpty)
                                      Text(
                                        payloadText,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                          fontSize: (titleFontSize),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    Row(
                                      children: [
                                       Text(
                                            isCallback ? 'Callback Request' : "Ticket ID: ${doc.id}",
                                            style: GoogleFonts.poppins(
                                              fontSize: (payloadText != null && payloadText.isNotEmpty
                                                  ? (titleFontSize - 2)
                                                  : titleFontSize),
                                              color: (payloadText != null && payloadText.isNotEmpty
                                                  ? Colors.black54
                                                  : Colors.black),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: doc.id));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("Ticket ID copied")),
                                            );
                                          },
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                                subtitle: Text(
                                  createdAtStr,
                                  style: GoogleFonts.poppins(
                                      fontSize: subtitleFontSize+2,
                                      color: Colors.grey),
                                ),
                                onTap: () {
                                  print("👉 Ticket tapped: ${doc.id}");
                                  if (isCallback) {
                                    print("   → This is a callback ticket. Showing dialog.");
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text('Callback Requested',
                                            style: GoogleFonts.poppins()),
                                        content: Text(
                                          'Admin will reach out to you soon.',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Text('OK',
                                                style: GoogleFonts.poppins()),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }
                                  final ticketId = doc.id;
                                  print("   → Navigating to /partner/${widget.serviceId}/support/ticket/$ticketId");
                                  _ChatPageLoader(
                                    serviceId: widget.serviceId,
                                    ticketId: null, // No ticket on this route
                                  );                                },
                              ),
                            ),
                            if (!isClosed) // Only show the LIVE indicator if not closed
                              Positioned(
                                bottom: 3,
                                right: 12,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8.0,
                                      height: 8.0,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'LIVE',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }




  /*Widget _buildLiveSessionsList() {
    final query = FirebaseFirestore.instance
        .collection('chatSessions')
        .where('participants', arrayContains: _uid)
        .where('mark_as_closed', isEqualTo: false)
        .orderBy('createdAt', descending: false);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Firestore index error: ${snapshot.error}');
          return Center(
            child: Text(
              '',
              style: GoogleFonts.poppins(),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final liveDocs = snapshot.data!.docs;

        // Inside _buildLiveSessionsList()
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Live Sessions',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: liveDocs.length,
                  itemBuilder: (context, index) {
                    final doc = liveDocs[index];
                    final chatId = doc.id;
                    final createdAtTimestamp = doc['createdAt'] as Timestamp?;
                    final createdAt = createdAtTimestamp?.toDate();
                    final timeString = createdAt != null
                        ? DateFormat('HH:mm').format(createdAt)
                        : 'Unknown time';
                    final dateString = createdAt != null
                        ? DateFormat('dd MMM yyyy').format(createdAt)
                        : 'Unknown date';

                    return FutureBuilder<String?>(
                      future: _getPayloadIfSecondIsPlusOne(chatId),
                      builder: (context, async) {
                        final payloadText = async.data;
                        // Removed the Stack and Positioned widgets here
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.red, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  leading: const Icon(Icons.chat_bubble, color: Colors.red),
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if ((payloadText ?? '').isNotEmpty)
                                        Text(
                                          payloadText!,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      Text(
                                        chatId,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Raised at $timeString • $dateString',
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                  onTap: () {
                                    context.go(
                                        '/partner/${widget.serviceId}/support/ticket/$chatId');
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                                  onPressed: () => _showDeleteDialog(context, chatId),
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
        );
      },
    );
  }*/

  void _showDeleteDialog(BuildContext context, String chatId) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning, size: 40, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Close Chat?',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to mark this session as closed?',
                  style: GoogleFonts.poppins(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text("Cancel", style: GoogleFonts.poppins()),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('chatSessions')
                            .doc(chatId)
                            .update({'mark_as_closed': true});
                        Navigator.of(ctx).pop();
                      },
                      child:
                      Text("Yes, Close", style: GoogleFonts.poppins()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _getPayloadIfSecondIsPlusOne(String chatId) async {
    final col = FirebaseFirestore.instance
        .collection('chatSessions')
        .doc(chatId)
        .collection('messages');

    final snap = await col.orderBy('ts', descending: false).limit(2).get();
    if (snap.docs.length < 2) return null;

    return snap.docs[1].data()['payload']?.toString();
  }
}


class _ChatPageLoader extends StatefulWidget {
  final String serviceId;
  final String? ticketId;

  const _ChatPageLoader({
    Key? key,
    required this.serviceId,
    this.ticketId,
  }) : super(key: key);

  @override
  State<_ChatPageLoader> createState() => _ChatPageLoaderState();
}

class _ChatPageLoaderState extends State<_ChatPageLoader> {
  late Future<Widget> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadChatPage(widget.serviceId, widget.ticketId);
  }

  @override
  void didUpdateWidget(covariant _ChatPageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceId != widget.serviceId || oldWidget.ticketId != widget.ticketId) {
      setState(() {
        _loadFuture = _loadChatPage(widget.serviceId, widget.ticketId);
      });
    }
  }

  Future<Widget> _loadChatPage(String serviceId, String? ticketId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return SignInPage(); // Protected by router, but good fallback
    }

    // Fetch the service provider's document
    final snap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .where('service_id', isEqualTo: serviceId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return const Center(child: Text("Error: Service provider profile not found."));
    }

    final d = snap.docs.first.data();

    // Extract the required fields (using the same fields as your _PartnerLoader)
    final shopName = d['shop_name'] as String? ?? '';
    final shopEmail = d['notification_email'] as String? ?? '';
    final shopPhone = d['dashboard_phone'] as String? ?? '';

    // Return the fully-formed SPChatPage
    return SPChatPage(
      initialOrderId: ticketId,
      serviceId: serviceId,
      shop_name: shopName,
      shop_email: shopEmail,
      shop_phone_number: shopPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _loadFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ReusableSplashScreen();
        }
        if (snap.hasError) {
          return Center(child: Text("Error loading chat: ${snap.error}"));
        }
        return snap.data!;
      },
    );
  }
}
