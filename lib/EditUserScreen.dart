import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditUserScreen extends StatefulWidget {
  final Map<String, dynamic>? user;

  EditUserScreen({this.user});

  @override
  _EditUserScreenState createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _idNumberController;
  late TextEditingController _plateNumberController;
  late TextEditingController _vehicleModelController;
  late TextEditingController _vehicleTypeController;
  late TextEditingController _emailController;
  bool _isLoading = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _idNumberController = TextEditingController();
    _plateNumberController = TextEditingController();
    _vehicleModelController = TextEditingController();
    _vehicleTypeController = TextEditingController();
    _emailController = TextEditingController();

    if (widget.user != null && widget.user!['full_name'] == null) {
      _fetchUserProfile(widget.user!['name']);
    } else {
      _populateFields(widget.user ?? {});
      _isFetching = false;
    }
  }

  void _populateFields(Map<String, dynamic> data) {
    _fullNameController.text = data['full_name'] ?? '';
    _idNumberController.text = data['id_number'] ?? '';
    _plateNumberController.text = data['plate_number'] ?? '';
    _vehicleModelController.text = data['vehicle_model'] ?? '';
    _vehicleTypeController.text = data['vehicle_type'] ?? '';
    _emailController.text = data['email'] ?? '';
  }

  Future<void> _fetchUserProfile(String name) async {
    try {
      final response = await http.get(
        Uri.parse('https://appfinity.vercel.app/profile/$name'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _populateFields(data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to fetch user data')),
        );
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() {
        _isFetching = false;
      });
    }
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final response = await http.post(
      Uri.parse('https://appfinity.vercel.app/profile/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': widget.user?['name'] ?? _fullNameController.text,
        'full_name': _fullNameController.text,
        'id_number': _idNumberController.text,
        'plate_number': _plateNumberController.text,
        'vehicle_model': _vehicleModelController.text,
        'vehicle_type': _vehicleTypeController.text,
        'email': _emailController.text,
      }),
    );

    setState(() => _isLoading = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Profile saved successfully!')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to save profile')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.user == null ? 'Create User' : 'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Color(0xFF71BFDC),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isFetching
          ? Center(child: CircularProgressIndicator(color: Color(0xFF18ACC1)))
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF71BFDC), Color(0xFFC0BDC5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(maxWidth: 400),
            child: Card(
              color: Colors.white,
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF1B92B5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.edit, size: 36, color: Color(0xFF18ACC1)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          widget.user == null ? 'Add New User' : 'Update Profile',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Fill in the user information below',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        SizedBox(height: 16),
                        Divider(thickness: 1, color: Colors.grey[300]),
                        SizedBox(height: 16),

                        _buildTextField('Full Name', _fullNameController, Icons.person),
                        SizedBox(height: 12),
                        _buildTextField('ID Number', _idNumberController, Icons.badge),
                        SizedBox(height: 12),
                        _buildTextField('Plate Number', _plateNumberController, Icons.directions_car),
                        SizedBox(height: 12),
                        _buildTextField('Vehicle Model', _vehicleModelController, Icons.motorcycle),
                        SizedBox(height: 12),
                        _buildTextField('Vehicle Type', _vehicleTypeController, Icons.directions_bus),
                        SizedBox(height: 12),
                        _buildTextField('Email', _emailController, Icons.email),

                        SizedBox(height: 24),
                        _isLoading
                            ? CircularProgressIndicator(color: Color(0xFF11A4B1))
                            : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _updateUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0C8798),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                            ),
                            child: Text(
                              widget.user == null ? 'Create User' : 'Update Profile',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: Colors.black),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Color(0xFF4CC7D3)),
        labelText: label,
        labelStyle: TextStyle(color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF49C6DC), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: (value) => value!.isEmpty ? 'Enter $label' : null,
    );
  }
}
