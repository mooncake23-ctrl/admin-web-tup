import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("https://appfinity.vercel.app/admin/add"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "name": _nameController.text.trim(),
          "password_hash": _passwordController.text.trim(), // raw password
        }),
      );

      final responseData = jsonDecode(response.body);
      print('Server Response: $responseData');

      if (response.statusCode == 200 && responseData["status"] == "ok") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Account created successfully!')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        throw Exception(responseData['message'] ?? 'Unknown error occurred');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF71BFDC), Color(0xFF9676D6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Container(
              width: min(400, MediaQuery.of(context).size.width * 0.9),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    _buildTextField(_emailController, 'Full Name', Icons.email),
                    SizedBox(height: 16),
                    SizedBox(height: 30),
                    _buildTextField(_nameController, 'Email', Icons.person),
                    SizedBox(height: 16),
                    _buildPasswordField(),
                    SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.3),
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                        'SIGN UP',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/login'),
                      child: Text('Already have an account? Login',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white),
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter $label';
        if (label == 'Name' && !value.contains('@')) return 'Invalid email';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.lock, color: Colors.white),
        labelText: 'Password',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter password';
        if (value.length < 6) return 'Password too short (min 6 chars)';
        return null;
      },
    );
  }
}
