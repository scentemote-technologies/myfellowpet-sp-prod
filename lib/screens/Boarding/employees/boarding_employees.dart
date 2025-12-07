import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BoardingEmployees extends StatefulWidget {
  final String shopId;
  final bool showAppBar;

  const BoardingEmployees({Key? key, required this.shopId, this.showAppBar = true}) : super(key: key);

  @override
  _BoardingEmployeesState createState() => _BoardingEmployeesState();
}

class _BoardingEmployeesState extends State<BoardingEmployees> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  final Map<int, TextEditingController> _nameControllers = {};
  final Map<int, TextEditingController> _phoneControllers = {};
  final Map<int, TextEditingController> _emailControllers = {};
  final Map<int, Map<String, String>> _originalEmployeeData = {};
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .where('shopId', isEqualTo: widget.shopId)
        .where('service_name', isEqualTo: 'Boarding')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
        title: Text(
          'Employee Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueGrey[900],
      )
          : null,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No data found.'));
                }

                final filteredDocs = snapshot.data!.docs;

                final employees = filteredDocs.expand((doc) {
                  final data = doc.data();
                  final employeeMaps = data['employees'] as List<dynamic>? ?? [];
                  return employeeMaps.map((emp) => emp as Map<String, dynamic>);
                }).toList();

                if (employees.isEmpty) {
                  return Center(child: Text('No employees found.'));
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16.0),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    final name = employee['name'] ?? '';
                    final phone = employee['phone'] ?? '';
                    final email = employee['email'] ?? '';

                    if (!_nameControllers.containsKey(index)) {
                      _nameControllers[index] = TextEditingController(text: name);
                      _phoneControllers[index] = TextEditingController(text: phone);
                      _emailControllers[index] = TextEditingController(text: email);
                      _originalEmployeeData[index] = {
                        'name': name,
                        'phone': phone,
                        'email': email,
                      };
                    }

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 5.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _editingIndex == index ? '' : 'Email: ${email}',
                                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (_editingIndex == index)
                                      IconButton(
                                        icon: Icon(Icons.save, color: Colors.green),
                                        onPressed: () => _saveEmployee(index),
                                      ),
                                    if (_editingIndex != index)
                                      IconButton(
                                        icon: Icon(Icons.edit, color: Colors.blueGrey[900]),
                                        onPressed: () {
                                          setState(() {
                                            _editingIndex = index;
                                          });
                                        },
                                      ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _confirmDeleteEmployee(index),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (_editingIndex == index)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextFormField(
                                  controller: _emailControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ),
                            if (_editingIndex != index)
                              SizedBox.shrink(), // Display nothing when not editing
                            SizedBox(height: 8.0),
                            Text(
                              'Name:',
                              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                            ),
                            if (_editingIndex == index)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextFormField(
                                  controller: _nameControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Name',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('${_originalEmployeeData[index]?['name'] ?? ''}', style: TextStyle(fontSize: 16.0)),
                              ),
                            SizedBox(height: 8.0),
                            Text(
                              'Phone:',
                              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                            ),
                            if (_editingIndex == index)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextFormField(
                                  controller: _phoneControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Phone',
                                    border: OutlineInputBorder(),
                                    hintText: 'Include the country code +91 while editing',
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('${_originalEmployeeData[index]?['phone'] ?? ''}', style: TextStyle(fontSize: 16.0)),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEmployeeDialog(),
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Add Employee', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900],
        tooltip: 'Add Employee',
      ),

    );
  }

  Future<void> _showAddEmployeeDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Employee'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 8.0),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 8.0),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  hintText: 'Include the country code +91',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newEmployee = {
                  'email': emailController.text,
                  'name': nameController.text,
                  'phone': phoneController.text,
                };

                await _addEmployee(newEmployee);
                Navigator.of(context).pop();
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addEmployee(Map<String, String> newEmployee) async {
    try {
      final filteredDocs = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .where('shopId', isEqualTo: widget.shopId)
          .where('service_name', isEqualTo: 'Boarding')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in filteredDocs.docs) {
        final employees = doc.data()['employees'] as List<dynamic>? ?? [];
        final updatedEmployees = [...employees, newEmployee];
        batch.update(doc.reference, {'employees': updatedEmployees});
      }

      await batch.commit();
      print('Employee added successfully');
    } catch (e) {
      print('Error adding employee: $e');
    }
  }

  Future<void> _confirmDeleteEmployee(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this employee?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Yes'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteEmployee(index);
    }
  }

  Future<void> _deleteEmployee(int index) async {
    try {
      final filteredDocs = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .where('shopId', isEqualTo: widget.shopId)
          .where('service_name', isEqualTo: 'Boarding')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in filteredDocs.docs) {
        final employees = doc.data()['employees'] as List<dynamic>? ?? [];
        final updatedEmployees = employees.asMap().entries
            .where((entry) => entry.key != index)
            .map((entry) => entry.value)
            .toList();
        batch.update(doc.reference, {'employees': updatedEmployees});
      }

      await batch.commit();
      print('Employee deleted successfully');
    } catch (e) {
      print('Error deleting employee: $e');
    }
  }

  Future<void> _saveEmployee(int index) async {
    try {
      final updatedEmployee = {
        'email': _emailControllers[index]?.text ?? '',
        'name': _nameControllers[index]?.text ?? '',
        'phone': _phoneControllers[index]?.text ?? '',
      };

      await _updateEmployeeData(index, updatedEmployee);

      setState(() {
        _editingIndex = null;
      });

      print('Employee saved successfully at index: $index');
    } catch (e) {
      print('Error saving employee: $e');
    }
  }

  Future<void> _updateEmployeeData(int index, Map<String, dynamic> updatedEmployee) async {
    try {
      final filteredDocs = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .where('shopId', isEqualTo: widget.shopId)
          .where('service_name', isEqualTo: 'Boarding')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in filteredDocs.docs) {
        final employees = doc.data()['employees'] as List<dynamic>? ?? [];
        final updatedEmployees = employees.asMap().map((i, emp) {
          if (i == index) {
            return MapEntry(i, updatedEmployee);
          }
          return MapEntry(i, emp);
        }).values.toList();
        batch.update(doc.reference, {'employees': updatedEmployees});
      }

      await batch.commit();
      print('Employee data updated successfully at index: $index');
    } catch (e) {
      print('Error updating employee data: $e');
    }
  }
}
