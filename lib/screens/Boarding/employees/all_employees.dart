import 'package:flutter/material.dart';
import 'boarding_employees.dart';

class AllEmployees extends StatefulWidget {
  final String serviceId;
  final String shopId;

  const AllEmployees({Key? key, required this.serviceId, required this.shopId}) : super(key: key);

  @override
  _AllEmployeesState createState() => _AllEmployeesState();
}

class _AllEmployeesState extends State<AllEmployees> {
  final List<String> _services = [
    'Boarding',
    'Vet',
    'Grooming',
    'Mortuary',
    'Store',
    'Sell',
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _services.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'All Employees',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blueGrey[900],
          bottom: TabBar(
            isScrollable: false,
            tabs: _services.map((service) {
              return Tab(
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    service,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        body: TabBarView(
          children: _services.map((service) {
            if (service == 'Boarding') {
              return BoardingEmployees(
                shopId: widget.shopId,
                showAppBar: false, // Hide the AppBar in this case
              );
            } else {
              return Center(
                child: Text('Content for $service tab'),
              );
            }
          }).toList(),
        ),
      ),
    );
  }
}
