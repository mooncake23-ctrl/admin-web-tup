import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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
      final response = await http.get(
        Uri.parse('https://appfinity.vercel.app/violations/all'),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('Fetch violations response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          violations = data.map((item) {
            return {
              'id': item[0]?.toString(),
              'name': item[1]?.toString(),
              'role': item[2]?.toString(),
              'status': item[3]?.toString(),
              'type': item[4]?.toString(),
              'info': item[5]?.toString(),
              'created_at': item[6]?.toString(),
            };
          }).toList();

          filteredViolations = violations.where((v) => v['status'] != 'resolved').toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        throw Exception('Failed to load violations: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackbar('Error fetching violations: ${e.toString()}');
      debugPrint('Error details: $e');
    }
  }

  Future<void> addViolation(String name, String info, String type) async {
    try {
      final response = await http.post(
        Uri.parse('https://appfinity.vercel.app/violations/rfid/add'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'info': info,
          'name': name,
          'role': 'user',
          'status': 'pending',
          'type': type,
        }),
      );

      debugPrint('Add violation request: ${response.request}');
      debugPrint('Add violation response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _showSuccessSnackbar('Violation added successfully!');
        await fetchViolations();
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ??
            responseData['error'] ??
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (e.toString().contains('already exists')) {
        _showErrorSnackbar('Violation for this user already exists');
      } else {
        _showErrorSnackbar('Failed to add violation: ${e.toString()}');
      }
    }
  }

  Future<void> resolveViolation(String name, String id) async {
    try {
      setState(() => isLoading = true);

      final resolveResponse = await http.put(
        Uri.parse('https://appfinity.vercel.app/violations/rfid/resolve/byname'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
        }),
      ).timeout(Duration(seconds: 10));

      debugPrint('Resolve violation response: ${resolveResponse.statusCode} - ${resolveResponse.body}');

      if (resolveResponse.statusCode == 200) {
        final deleteResponse = await http.delete(
          Uri.parse('https://appfinity.vercel.app/violations/delete/$id'),
          headers: {'accept': 'application/json'},
        ).timeout(Duration(seconds: 10));

        debugPrint('Delete violation response: ${deleteResponse.statusCode} - ${deleteResponse.body}');

        if (deleteResponse.statusCode == 200) {
          final responseData = json.decode(deleteResponse.body);
          _showSuccessSnackbar(responseData['message'] ?? 'Violation resolved and deleted successfully!');
          await fetchViolations();
        } else {
          final errorData = json.decode(deleteResponse.body);
          throw Exception(errorData['message'] ??
              'Failed to delete violation. Status code: ${deleteResponse.statusCode}');
        }
      } else {
        final errorData = json.decode(resolveResponse.body);
        throw Exception(errorData['message'] ??
            'Failed to resolve violation. Status code: ${resolveResponse.statusCode}');
      }
    } on TimeoutException {
      _showErrorSnackbar('Request timed out. Please check your connection.');
    } on http.ClientException {
      _showErrorSnackbar('Network error. Please check your connection.');
    } catch (e) {
      debugPrint('Error resolving/deleting violation: $e');
      _showErrorSnackbar('Failed to process violation: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'speeding': return Colors.red[400]!;
      case 'reckless': return Colors.orange[400]!;
      case 'unauthorized': return Colors.purple[400]!;
      default: return Colors.grey;
    }
  }

  void showAddViolationDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final infoController = TextEditingController();
    String selectedType = "no exit scan";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "Report Violation",
                style: TextStyle(color: Colors.black),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Email",
                          labelStyle: TextStyle(color: Colors.black),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(color: Colors.black),
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: infoController,
                        decoration: const InputDecoration(
                          labelText: "Violation Details",
                          labelStyle: TextStyle(color: Colors.black),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(color: Colors.black),
                        maxLines: 3,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        items: ['no exit scan', 'reckless parking', 'unauthorized', 'other']
                            .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type[0].toUpperCase() + type.substring(1),
                            style: const TextStyle(color: Colors.black),
                          ),
                        ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedType = value!;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: "Violation Type",
                          labelStyle: TextStyle(color: Colors.black),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(color: Colors.black),
                        dropdownColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.black)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      await addViolation(
                        nameController.text.trim(),
                        infoController.text.trim(),
                        selectedType,
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text("Report", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _secondaryColor,
      appBar: AppBar(
        title: Text('Violations', style: TextStyle(color: Colors.white)),
        backgroundColor: _primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchViolations,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddViolationDialog(context),
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: _primaryColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : filteredViolations.isEmpty
                ? Center(child: Text('No active violations found'))
                : RefreshIndicator(
              onRefresh: fetchViolations,
              child: ListView.builder(
                itemCount: filteredViolations.length,
                itemBuilder: (context, index) {
                  final violation = filteredViolations[index];
                  return _buildViolationCard(violation);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationCard(Map<String, dynamic> violation) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    violation['name'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: getTypeColor(violation['type'] ?? 'other').withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (violation['type'] ?? 'other').toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: getTypeColor(violation['type'] ?? 'other'),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                violation['info'] ?? 'No details',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey[200]),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: violation['status'] == 'pending'
                          ? Colors.orange[50]
                          : Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Status: ${violation['status'] ?? 'unknown'}',
                      style: TextStyle(
                        color: violation['status'] == 'pending'
                            ? Colors.orange[800]
                            : Colors.green[800],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (violation['status'] == 'pending')
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      ),
                      onPressed: () => resolveViolation(violation['name'], violation['id']),
                      child: Text(
                        'Resolve',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}