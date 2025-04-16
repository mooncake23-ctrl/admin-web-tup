import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class CreateUserScreen extends StatefulWidget {
  @override
  _CreateUserScreenState createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isUploading = false;
  final Color primaryColor = Color(0xFF71BFDC);
  final Color backgroundColor = Colors.grey[50]!;
  final Color cardBackgroundColor = Colors.white;
  final Color textColor = Colors.black;

  // Controllers
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController rfidController = TextEditingController();
  TextEditingController roleController = TextEditingController(text: 'user');
  TextEditingController assignedSlotController = TextEditingController();
  TextEditingController fullnameController = TextEditingController();
  TextEditingController idNumberController = TextEditingController();
  TextEditingController plateNumberController = TextEditingController();
  TextEditingController vehicleTypeController = TextEditingController();
  TextEditingController vehicleModelController = TextEditingController();

  bool _obscurePassword = true;

  void _resetForm() {
    setState(() {
      emailController.clear();
      passwordController.clear();
      rfidController.clear();
      roleController.text = 'user';
      assignedSlotController.clear();

      fullnameController.clear();
      idNumberController.clear();
      plateNumberController.clear();
      vehicleTypeController.clear();
      vehicleModelController.clear();
    });
  }

  Future<void> _createUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isUploading = true);

      try {
        final userData = {
          "email": emailController.text.trim(),
          "name": emailController.text.trim(),
          "password_hash": passwordController.text.trim(),
          "rfid": rfidController.text.trim(),
          "role": roleController.text.trim(),
          "assignedslot": assignedSlotController.text.trim().isEmpty
              ? "n/a"
              : assignedSlotController.text.trim(),
        };

        final userResponse = await http.post(
          Uri.parse('https://appfinity.vercel.app/users/add'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(userData),
        );

        if (userResponse.statusCode >= 200 && userResponse.statusCode < 300) {
          final profileData = {
            "name": emailController.text.trim(),
            "full_name": fullnameController.text.trim(),
            "id_number": idNumberController.text.trim(),
            "plate_number": plateNumberController.text.trim(),
            "vehicle_model": vehicleModelController.text.trim(),
            "vehicle_type": vehicleTypeController.text.trim(),

          };

          final profileResponse = await http.post(
            Uri.parse('https://appfinity.vercel.app/profile/add'),
            headers: {
              'Content-Type': 'application/json',
              'accept': 'application/json',
            },
            body: jsonEncode(profileData),
          );

          if (profileResponse.statusCode >= 200 && profileResponse.statusCode < 300) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('User created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            _resetForm();
          } else {
            throw Exception('Profile creation failed: ${profileResponse.body}');
          }
        } else {
          throw Exception('User creation failed: ${userResponse.body}');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Create New User', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetForm,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildSectionCard(
                title: 'Account Information',
                icon: Icons.account_circle,
                children: [
                  _buildTextField(emailController, 'Email', Icons.email),
                  SizedBox(height: 12),
                  _buildPasswordField(),
                  SizedBox(height: 12),
                  _buildTextField(rfidController, 'RFID', Icons.credit_card),

                  SizedBox(height: 12),
                  _buildTextField(
                    assignedSlotController,
                    'Assigned Slot (Make this Blank, this is for emergency purposes only)',
                    Icons.local_parking,
                    required: false,
                  ),
                ],
              ),
              SizedBox(height: 20),
              _buildSectionCard(
                title: 'Profile Information',
                icon: Icons.person_outline,
                children: [
                  _buildTextField(fullnameController, 'Full Name', Icons.person),
                  SizedBox(height: 12),
                  _buildTextField(idNumberController, 'ID Number', Icons.badge),
                  SizedBox(height: 12),
                  _buildTextField(plateNumberController, 'Plate Number', Icons.directions_car),
                  SizedBox(height: 12),
                  _buildTextField(vehicleTypeController, 'Vehicle Type', Icons.directions_car),
                  SizedBox(height: 12),
                  _buildTextField(vehicleModelController, 'Vehicle Model', Icons.directions_car),
                ],
              ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _createUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isUploading
                      ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'CREATE USER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardBackgroundColor,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool required = true,
      }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: cardBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor),
        ),
      ),
      validator: required
          ? (value) => value!.isEmpty ? '$label is required' : null
          : null,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: passwordController,
      obscureText: _obscurePassword,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(Icons.lock, color: primaryColor),
        filled: true,
        fillColor: cardBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: primaryColor,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) => value!.isEmpty ? 'Password is required' : null,
    );
  }
}