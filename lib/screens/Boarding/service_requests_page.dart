import 'package:flutter/material.dart';
import 'boarding_requests.dart';


class ServiceRequestsPage extends StatefulWidget {
  final String serviceId;

  ServiceRequestsPage({required this.serviceId});

  @override
  _ServiceRequestsPageState createState() => _ServiceRequestsPageState();
}

class _ServiceRequestsPageState extends State<ServiceRequestsPage> {
  final List<String> _serviceNames = ['Boarding'];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _serviceNames.length,
      child: Scaffold(
        body: BoardingRequests(serviceId: widget.serviceId),
      ),
    );
  }
}