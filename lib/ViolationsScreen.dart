import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ViolationsScreen extends StatefulWidget {
  @override
  _ViolationsScreenState createState() => _ViolationsScreenState();
}

class _ViolationsScreenState extends State<ViolationsScreen> {
  List violations = [];
  List filteredViolations = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final Color _primaryColor = Color(0xFF71BFDC);
  final Color _secondaryColor = Color(0xFFF3F1F1);
  final Color _cardColor = Colors.white;
  final Color _textColor = Color(0xFF5D4037);

  @override
  void initState() {
    super.initState();
    fetchViolations();
    _searchController.addListener(_filterViolations);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterViolations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredViolations = violations.where((violation) {
        final name = violation['name']?.toString().toLowerCase() ?? '';
        final info = violation['info']?.toString().toLowerCase() ?? '';
        return name.contains(query) || info.contains(query);
      }).toList();
    });
  }

  Future<void> fetchViolations() async {
    try {
      setState(() => isLoading = true);
      final response = await http.get(Uri.parse('https://appfinity.vercel.app/violations-content'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey("violations")) {
          setState(() {
            violations = List.from(data["violations"]);
            filteredViolations = List.from(violations);
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> addViolation(String name, String info, String role, String status, String type) async {
    try {
      final response = await http.post(
        Uri.parse('https://appfinity.vercel.app/violations/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'info': info,
          'role': role,
          'status': status,
          'type': type
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Violation added successfully!'),
            backgroundColor: _primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        await fetchViolations();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding violation!'),
          backgroundColor: Colors.red[300],
        ),
      );
    }
  }

  Future<void> deleteViolation(String name) async {
    try {
      final response = await http.delete(
        Uri.parse('https://appfinity.vercel.app/violations/delete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'status': 'active'}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Violation resolved!'),
            backgroundColor: _primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        await fetchViolations();
      } else {
        final responseData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Failed to resolve violation'),
            backgroundColor: Colors.red[300],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resolving violation!'),
          backgroundColor: Colors.red[300],
        ),
      );
    }
  }

  void showAddViolationDialog() {
    final formKey = GlobalKey<FormState>();
    TextEditingController nameController = TextEditingController();
    TextEditingController infoController = TextEditingController();
    String selectedRole = "user";
    String selectedStatus = "active";
    String selectedType = "low";

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Report Violation",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      labelStyle: TextStyle(color: Colors.black87),
                      hintStyle: TextStyle(color: Colors.black54),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                    style: TextStyle(color: Colors.black87),
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: infoController,
                    decoration: InputDecoration(
                      labelText: "Violation Details",
                      labelStyle: TextStyle(color: Colors.black87),
                      hintStyle: TextStyle(color: Colors.black54),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 3,
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                    style: TextStyle(color: Colors.black87),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    items: ['low', 'medium', 'high']
                        .map((type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(
                        type[0].toUpperCase() + type.substring(1),
                        style: TextStyle(color: Colors.black54),
                      ),
                    ))
                        .toList(),
                    onChanged: (value) => selectedType = value!,
                    decoration: InputDecoration(
                      labelText: "Severity",
                      labelStyle: TextStyle(color: Colors.black),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    style: TextStyle(color: Colors.black),
                    dropdownColor: Colors.white,
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            addViolation(
                              nameController.text,
                              infoController.text,
                              selectedRole,
                              selectedStatus,
                              selectedType,
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: Text("Report", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color getTypeColor(String type) {
    switch (type) {
      case 'high':
        return Colors.red[400]!;
      case 'medium':
        return Colors.orange[400]!;
      case 'low':
        return Colors.green[400]!;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _secondaryColor,
      appBar: AppBar(
        title: Text(
          'Violations',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchViolations,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddViolationDialog,
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: _primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: 'Search Email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _primaryColor),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : filteredViolations.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in, size: 50, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No violations found',
                    style: TextStyle(
                      fontSize: 18,
                      color: _textColor,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              color: _primaryColor,
              onRefresh: fetchViolations,
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredViolations.length,
                itemBuilder: (context, index) {
                  final violation = filteredViolations[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    color: _cardColor,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                violation['name'] ?? 'Unknown User',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _textColor,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: getTypeColor(violation['type'] ?? 'low').withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: getTypeColor(violation['type'] ?? 'low'),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  (violation['type'] ?? 'low').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: getTypeColor(violation['type'] ?? 'low'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            violation['info'] ?? 'No details provided',
                            style: TextStyle(color: _textColor),
                          ),
                          SizedBox(height: 12),
                          Divider(height: 1, color: Colors.grey[300]),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                                  SizedBox(width: 4),
                                  Text(
                                    violation['role'] ?? 'Unknown',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.circle, size: 8, color: _primaryColor),
                                  SizedBox(width: 4),
                                  Text(
                                    violation['status'] ?? 'Unknown',
                                    style: TextStyle(fontSize: 12, color: _textColor),
                                  ),
                                ],
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: () => deleteViolation(violation['name']),
                                child: Text(
                                  'Resolve',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}