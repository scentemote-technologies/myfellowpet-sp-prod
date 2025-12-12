import 'dart:io';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../SPChatWidget.dart';
import '../roles/role_service.dart';

// An enum to make tab logic cleaner and more readable.
enum TaskStatus { pending, underReview, completed }

class TasksScreen extends StatefulWidget {
  final String serviceId;
  final String employeeId;
  const TasksScreen(
      {super.key, required this.serviceId, required this.employeeId});

  @override
  _TasksScreenState createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  // Brand Colors
  static const Color primaryColor = Color(0xFF2CB4B6);
  static const Color accentColor = Color(0xFFF67B0D);

  // Caches for each tab state.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _pendingCache = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _underReviewCache = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _completedCache = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchTerm = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _taskStream(TaskStatus status) {
    Query query = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('employees')
        .doc(widget.employeeId)
        .collection('tasks');

    switch (status) {
      case TaskStatus.pending:
        return query
            .where('task_done', isEqualTo: false)
            .where(Filter.or(Filter('hasSubmissions', isEqualTo: false),
            Filter('hasSubmissions', isNull: true)))
            .orderBy('createdAt', descending: true)
            .snapshots() as Stream<QuerySnapshot<Map<String, dynamic>>>;
      case TaskStatus.underReview:
        return query
            .where('task_done', isEqualTo: false)
            .where('hasSubmissions', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots() as Stream<QuerySnapshot<Map<String, dynamic>>>;
      case TaskStatus.completed:
        return query
            .where('task_done', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots() as Stream<QuerySnapshot<Map<String, dynamic>>>;
    }
  }

  Widget _buildTaskList(TaskStatus status) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _taskStream(status),
      builder: (ctx, snap) {
        if (snap.hasError) {
          print("🔥🔥🔥 FIRESTORE QUERY ERROR: ${snap.error}");
          return Center(
              child: Text('Error loading tasks.',
                  style: GoogleFonts.poppins()));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: primaryColor));
        }

        final fetched = snap.data!.docs;
        List<QueryDocumentSnapshot<Map<String, dynamic>>> currentList;
        switch (status) {
          case TaskStatus.pending:
            _pendingCache = List.from(fetched);
            currentList = _pendingCache;
            break;
          case TaskStatus.underReview:
            _underReviewCache = List.from(fetched);
            currentList = _underReviewCache;
            break;
          case TaskStatus.completed:
            _completedCache = List.from(fetched);
            currentList = _completedCache;
            break;
        }

        final docs = _searchTerm.isEmpty
            ? currentList
            : currentList.where((d) {
          final t = (d.data()['title'] as String?)?.toLowerCase() ?? '';
          return t.contains(_searchTerm) ||
              d.id.toLowerCase().contains(_searchTerm);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt_rounded,
                    size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No tasks here!',
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    'Tasks for this category will appear on this screen.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 16, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(builder: (context, constraints) {
          return ListView.builder(
            padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth > 800 ? 48 : 16,
                vertical: 24),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _buildTaskCard(doc);
            },
          );
        });
      },
    );
  }

  Widget _buildTaskCard(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final startDt = (data['start_ts'] as Timestamp?)?.toDate();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final endDt = (data['end_ts'] as Timestamp?)?.toDate();

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.black)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: LayoutBuilder(builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 500;
          return Flex(
            direction: isWide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isWide ? 3 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? 'Untitled Task',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Task ID: ${doc.id}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black87, // darker than grey
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6), // spacing between text & icon
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16, color: Colors.black87),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: doc.id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Copied to clipboard")),
                            );
                          },
                          padding: EdgeInsets.zero, // remove extra padding
                          constraints: const BoxConstraints(), // make it compact
                        ),
                      ],
                    ),
                    const SizedBox(height: 10), // spacing between text & icon


                    if (!isWide) const Divider(height: 24),
                    ExpandableText(data['description'] ?? '-'),

                  ],
                ),
              ),
              if (isWide) const SizedBox(width: 24),
              if (!isWide) const SizedBox(height: 16),
              Expanded(
                flex: isWide ? 2 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                        Icons.calendar_today_outlined,
                        'Task created at',
                        createdAt != null
                            ? DateFormat.yMMMd().add_jm().format(createdAt)
                            : '-'),
                    _buildInfoRow(
                      Icons.flag_outlined,
                      'Task created by',
                      "${data['createdByName'] ?? 'NA'} (${data['createdByRole'] ?? 'NA'})",
                    ),
                    SizedBox(height: 5),
                    _buildInfoRow(
                        Icons.calendar_today_outlined,
                        'Start Time',
                        startDt != null
                            ? DateFormat.yMMMd().add_jm().format(startDt)
                            : '-'),
                    _buildInfoRow(
                        Icons.flag_outlined,
                        'End Time',
                        endDt != null
                            ? DateFormat.yMMMd().add_jm().format(endDt)
                            : '-'),

                  ],
                ),
              ),
              if (!isWide) const SizedBox(height: 16),
              _buildActionButtons(doc, data),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(  // <--- The solution is here
            child: Text.rich(
              TextSpan(
                text: '$label: ',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54),
                children: [
                  TextSpan(
                    text: value,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.normal, color: Colors.black87),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      DocumentSnapshot doc, Map<String, dynamic> data) {
    final me = context.watch<UserNotifier>().me;
    final isDone = data['task_done'] as bool? ?? false;
    final hasSubmissions = data['hasSubmissions'] as bool? ?? false;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isDone)
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file_rounded, size: 18, color: Colors.white,),
            label: Text('Submit Task', style: GoogleFonts.poppins()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showCompleteDialog(doc.id),
          ),
        if (!isDone && (me?.role == 'Owner' || me?.role == 'Manager'))
          const SizedBox(height: 8),
        if (!isDone && (me?.role == 'Owner' || me?.role == 'Manager'))
          TextButton.icon(
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white,),
            label: Text('Mark as Done', style: GoogleFonts.poppins()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),            onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (dCtx) =>AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.black87),
                ),
                backgroundColor: Colors.white,
                title: Text(
                  'Mark as done?',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                content: Text(
                  'This will mark the task as complete and move it to the completed tab. Are you sure?',
                  style: GoogleFonts.poppins(color: Colors.black87),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dCtx).pop(false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(color: Colors.black87),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(dCtx).pop(true),
                    child: Text(
                      'Yes, Mark Done',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await FirebaseFirestore.instance
                  .collection('users-sp-boarding')
                  .doc(widget.serviceId)
                  .collection('employees')
                  .doc(widget.employeeId)
                  .collection('tasks')
                  .doc(doc.id)
                  .update({'task_done': true});
            }
          },
          ),
        if (hasSubmissions) const SizedBox(height: 8),
        if (hasSubmissions)
          OutlinedButton.icon(
            icon: const Icon(Icons.history_rounded, size: 18, color: Colors.white,),
            label: Text('Submissions', style: GoogleFonts.poppins(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              side: const BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showHistoryDialog(doc.id),
          ),
      ],
    );
  }
  Future<void> _showHistoryDialog(String taskId) async {
    // get the employee name from parent doc
    final empSnap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('employees')
        .doc(widget.employeeId)
        .get();

    final employeeName = empSnap.data()?['name'] ?? 'Unknown';

    // get task history
    final snaps = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('employees')
        .doc(widget.employeeId)
        .collection('tasks')
        .doc(taskId)
        .collection('task_history')
        .orderBy('submittedAt', descending: true)
        .get();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Submission History',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: snaps.docs.isEmpty
                  ? [Text('No submissions yet.', style: GoogleFonts.poppins())]
                  : snaps.docs.asMap().entries.map((entry) {
                final h = entry.value.data();
                final at = (h['submittedAt'] as Timestamp).toDate();
                final photos = List<String>.from(h['photos'] ?? []);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // date
                      Text(
                        DateFormat.yMMMd().add_jm().format(at),
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryColor),
                      ),
                      const SizedBox(height: 4),
                      // submitted by
                      Text(
                        'Submitted by $employeeName',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (photos.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: photos.map((url) {
                            return GestureDetector(
                              onTap: () => _showImageDialog(context, url),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(url,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover),
                              ),
                            );
                          }).toList(),
                        )
                      else
                        Text('No photos submitted.',
                            style: GoogleFonts.poppins(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close',
                style: GoogleFonts.poppins(
                    color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: Image.network(imageUrl),
          ),
        ),
      ),
    );
  }

  Future<void> _showCompleteDialog(String taskId) async {
    bool confirmed = false;
    List<XFile> images = [];
    List<Uint8List> webImages = [];
    List<String> webNames = [];

    Future<void> pickImages() async {
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.image,
          withData: true,
        );
        if (result != null) {
          webImages = result.files.take(3).map((pf) {
            webNames.add(pf.name);
            return pf.bytes!;
          }).toList();
        }
      } else {
        final picker = ImagePicker();
        final pics =
        await picker.pickMultiImage(maxWidth: 800, maxHeight: 800);
        images = pics.take(3).toList();
      }
    }

    Future<List<String>> uploadPhotos() async {
      final bucket = FirebaseStorage.instance;
      List<String> urls = [];

      if (kIsWeb) {
        for (int i = 0; i < webImages.length; i++) {
          final bytes = webImages[i];
          final name = webNames[i];
          final path =
              'tasks/${widget.employeeId}/$taskId/${DateTime.now().millisecondsSinceEpoch}_$name';
          final ref = bucket.ref(path);
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
          urls.add(await ref.getDownloadURL());
        }
      } else {
        for (var img in images) {
          final path =
              'tasks/${widget.employeeId}/$taskId/${DateTime.now().millisecondsSinceEpoch}.jpg';
          final ref = bucket.ref(path);
          await ref.putFile(File(img.path));
          urls.add(await ref.getDownloadURL());
        }
      }
      return urls;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) {
          final totalPicked = kIsWeb ? webImages.length : images.length;

          return AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Submit Task',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add up to 3 photos as proof of completion.',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: confirmed,
                        onChanged: (v) => setState(() => confirmed = v!),
                        activeColor: primaryColor,
                      ),
                      Expanded(
                        child: Text(
                          "I confirm I have completed this task.",
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_a_photo_outlined, color: Colors.black87,),
                    label: Text('Add Photos ($totalPicked/3)',
                        style: GoogleFonts.poppins(color: Colors.black87,fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Colors.black87),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await pickImages();
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  if (totalPicked > 0)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(totalPicked, (i) {
                        Widget imgWidget = kIsWeb
                            ? Image.memory(webImages[i],
                            width: 80, height: 80, fit: BoxFit.cover)
                            : Image.file(File(images[i].path),
                            width: 80, height: 80, fit: BoxFit.cover);
                        return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imgWidget);
                      }),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx2).pop(),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.black87  )),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (confirmed && totalPicked > 0)
                    ? () async {
                  final urls = await uploadPhotos();
                  final taskRef = FirebaseFirestore.instance
                      .collection('users-sp-boarding')
                      .doc(widget.serviceId)
                      .collection('employees')
                      .doc(widget.employeeId)
                      .collection('tasks')
                      .doc(taskId);

                  await taskRef.collection('task_history').add({
                    'submittedBy':
                    Provider.of<UserNotifier>(context, listen: false)
                        .me!
                        .uid,
                    'submittedAt': Timestamp.now(),
                    'photos': urls,
                  });

                  await taskRef.update({'hasSubmissions': true});

                  if (mounted) Navigator.of(ctx2).pop();
                }
                    : null,
                child: Text('Submit', style: GoogleFonts.poppins()),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<UserNotifier>().me;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text('My Tasks',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              backgroundColor: primaryColor,
              floating: true,
              pinned: true,
              snap: true,
              elevation: 2,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: accentColor,
                indicatorWeight: 4,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(child: FittedBox(child: Text('Pending'))),
                  Tab(child: FittedBox(child: Text('Under Review'))),
                  Tab(child: FittedBox(child: Text('Completed'))),
                ],
              ),
            ),
          ];
        },
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  hintText: 'Search by task title or ID...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search, color: primaryColor),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTaskList(TaskStatus.pending),
                  _buildTaskList(TaskStatus.underReview),
                  _buildTaskList(TaskStatus.completed),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: (me?.role == 'Manager' || me?.role == 'Owner')
          ? FloatingActionButton.extended(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        onPressed: () => _showAddTaskDialog(context, me?.uid ?? '', me?.role ?? '', me?.name ?? ''),
        icon: const Icon(Icons.add),
        label: Text('Add Task',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 8,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      )
          : null,
    );
  }

  void _showAddTaskDialog(BuildContext context, String managerUid,String role,String name) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime startDate = DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();
    DateTime endDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay endTime = TimeOfDay(hour: endDate.hour, minute: endDate.minute);

    Future<DateTime?> _pickDate(DateTime initial) async =>
        await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(primary: primaryColor),
                buttonTheme:
                const ButtonThemeData(textTheme: ButtonTextTheme.primary),
              ),
              child: child!,
            );
          },
        );

    Future<TimeOfDay?> _pickTime(TimeOfDay initial) async =>
        await showTimePicker(
          context: context,
          initialTime: initial,
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(primary: primaryColor),
                buttonTheme:
                const ButtonThemeData(textTheme: ButtonTextTheme.primary),
              ),
              child: child!,
            );
          },
        );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Assign New Task',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: StatefulBuilder(builder: (ctx2, setState) {
            return SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                          labelText: 'Task Title',
                          labelStyle: GoogleFonts.poppins(),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      maxLines: 4,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: GoogleFonts.poppins(),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))),
                    ),
                    const SizedBox(height: 16),
                    _buildDateTimePicker(
                      label: 'Start',
                      date: startDate,
                      time: startTime,
                      onDateChanged: (d) => setState(() => startDate = d),
                      onTimeChanged: (t) => setState(() => startTime = t),
                      pickDate: _pickDate,
                      pickTime: _pickTime,
                    ),
                    const SizedBox(height: 12),
                    _buildDateTimePicker(
                      label: 'End',
                      date: endDate,
                      time: endTime,
                      onDateChanged: (d) => setState(() => endDate = d),
                      onTimeChanged: (t) => setState(() => endTime = t),
                      pickDate: _pickDate,
                      pickTime: _pickTime,
                    ),
                  ],
                ),
              ),
            );
          }),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.black87  )),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                final title = titleController.text.trim();
                final desc = descController.text.trim();
                final startDt = DateTime(startDate.year, startDate.month,
                    startDate.day, startTime.hour, startTime.minute);
                final endDt = DateTime(endDate.year, endDate.month,
                    endDate.day, endTime.hour, endTime.minute);

                if (title.isEmpty || desc.isEmpty || startDt.isAfter(endDt)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.redAccent,
                      content: Text(
                        (title.isEmpty || desc.isEmpty)
                            ? 'All fields are required.'
                            : 'End date must come after the start date.',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  );
                  return;
                }

                final taskData = {
                  'title': title,
                  'description': desc,
                  'start_ts': Timestamp.fromDate(startDt),
                  'end_ts': Timestamp.fromDate(endDt),
                  'createdAt': Timestamp.now(),
                  'createdBy': managerUid,
                  'task_done': false,
                  'hasSubmissions': false,
                  'createdByRole': role,
                  'createdByName':name
                };

                await FirebaseFirestore.instance
                    .collection('users-sp-boarding')
                    .doc(widget.serviceId)
                    .collection('employees')
                    .doc(widget.employeeId)
                    .collection('tasks')
                    .add(taskData);

                if (mounted) Navigator.of(ctx).pop();
              },
              child: Text('Assign Task', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required Function(DateTime) onDateChanged,
    required Function(TimeOfDay) onTimeChanged,
    required Future<DateTime?> Function(DateTime) pickDate,
    required Future<TimeOfDay?> Function(TimeOfDay) pickTime,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              child: InkWell(
                onTap: () async {
                  final d = await pickDate(date);
                  if (d != null) onDateChanged(d);
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8)),
                  child: FittedBox(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMM d, yyyy').format(date),
                            style: GoogleFonts.poppins(fontSize: 14)), // Set font size
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_today,
                            size: 18, color: primaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: InkWell(
                onTap: () async {
                  final t = await pickTime(time);
                  if (t != null) onTimeChanged(t);
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8)),
                  child: FittedBox(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(time.format(context), style: GoogleFonts.poppins(fontSize: 14)), // Set font size
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time,
                            size: 18, color: primaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ExpandableText extends StatefulWidget {
  final String text;
  const ExpandableText(this.text, {super.key});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: isExpanded ? null : 2,
          overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        InkWell(
          onTap: () => setState(() => isExpanded = !isExpanded),
          child: Text(
            isExpanded ? "Show less" : "Show more",
            style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}