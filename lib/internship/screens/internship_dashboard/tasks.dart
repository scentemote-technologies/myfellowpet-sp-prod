import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserTasksPage extends StatefulWidget {
  final String documentId;

  // Constructor that accepts documentId (domain/internship ID)
  UserTasksPage({required this.documentId});

  @override
  _UserTasksPageState createState() => _UserTasksPageState();
}

class _UserTasksPageState extends State<UserTasksPage> {
  late String documentId;
  bool isLoading = true;
  List<DocumentSnapshot> tasks = [];
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    documentId = widget.documentId;
    _getCurrentUserId();
  }

  Future<void> _getCurrentUserId() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          currentUserId = user.uid;
        });
        _fetchTasks();
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No user is logged in.")),
        );
      }
    } catch (e) {
      print("Error fetching user UID: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchTasks() async {
    if (currentUserId == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('targetId', isEqualTo: currentUserId)
          .get();

      final filteredTasks = querySnapshot.docs.where((task) {
        final taskData = task.data() as Map<String, dynamic>;
        final targetId = taskData['targetId'] ?? '';
        return targetId == currentUserId;
      }).toList();

      setState(() {
        tasks = filteredTasks;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching tasks: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Function to mark a task as completed
  Future<void> _markTaskAsCompleted(String taskId) async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .update({'status': 'Completed'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Task marked as completed!")),
      );
      _fetchTasks(); // Refresh tasks to reflect changes
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating task: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery to determine screen size
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWideScreen = screenWidth > 800; // Adjust breakpoint as needed

    return Scaffold(
        appBar: AppBar(
          title: Text(
            "My Tasks",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.black,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : tasks.isEmpty
            ? Center(
          child: Text(
            "No tasks assigned to you for this internship/domain.",
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        )
            : isWideScreen
        // For wide screens, center content in a ConstrainedBox
            ? Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800),
            child: _buildTaskList(),
          ),
        )
        // For smaller screens, just display the list
            : _buildTaskList(),
    );
  }

  Widget _buildTaskList() {
    return ListView.builder(
      itemCount: tasks.length,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemBuilder: (context, index) {
        final task = tasks[index];
        final taskId = task.id;
        final taskData = task.data() as Map<String, dynamic>;
        final isCompleted = taskData['status'] == 'Completed';

        return Card(
          color: isCompleted ? Colors.green[100] : Colors.white,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                taskData['name'] ?? 'Unnamed Task',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isCompleted ? Colors.green : Colors.black,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  taskData['description'] ?? 'No description',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ),
              trailing: ElevatedButton(
                onPressed: isCompleted
                    ? null
                    : () => _markTaskAsCompleted(taskId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  isCompleted ? "Completed" : "Mark as Done",
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
