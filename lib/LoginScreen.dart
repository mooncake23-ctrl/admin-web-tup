import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'SignUpScreen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final response = await http.post(
          Uri.parse('https://appfinity.vercel.app/admin/login'),
          headers: {
            'Content-Type': 'application/json',
            'accept': 'application/json',
          },
          body: jsonEncode({
            'name': _emailController.text.trim(),
            'password_hash': _passwordController.text.trim(),
          }),
        );

        if (response.statusCode == 200) {
          // Successful login
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          // Handle error response
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['message'] ?? 'Login failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF71BFDC),
              Color(0xFF9676D6),
            ],
          ),
        ),
        child: isPortrait
            ? SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildWelcomeSection(),
                const SizedBox(height: 40),
                _buildLoginForm(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        )
            : Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 80, right: 40),
                child: _buildWelcomeSection(),
              ),
            ),
            Container(
              width: screenWidth * 0.35,
              padding: const EdgeInsets.all(40),
              child: Center(
                child: SingleChildScrollView(
                  child: _buildLoginForm(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 200),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Builder(
                builder: (context) {
                  try {
                    return Image.asset(
                      'assets/images/eto.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint("Image load error: $error");
                        return Icon(Icons.image_not_supported,
                            color: Colors.white.withOpacity(0.5));
                      },
                    );
                  } catch (e) {
                    debugPrint("Image exception: $e");
                    return Icon(Icons.error_outline,
                        color: Colors.red.withOpacity(0.7));
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Welcome Back!",
            style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Efficiently manage student parking on campus with our powerful Admin Dashboard — featuring Real-time Insights",
            style: TextStyle(
              fontSize: 25,
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          _buildFeatureRow(Icons.local_parking, "Slot Monitoring"),
          const SizedBox(height: 10),
          _buildFeatureRow(Icons.people_alt, "User Management"),
          const SizedBox(height: 10),
          _buildFeatureRow(Icons.history, "Parking History Access"),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Admin Login",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 30),
            _buildTextField(_emailController, "Email", Icons.person_outline),
            const SizedBox(height: 20),
            _buildPasswordField(_passwordController, "Password"),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: true,
                      onChanged: (value) {},
                      fillColor: MaterialStateProperty.resolveWith<Color>(
                            (states) => Colors.white,
                      ),
                      checkColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Text("Remember me",
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text("Forgot password?",
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue,
                ),
              )
                  : const Text("LOGIN",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 25),
            const Divider(color: Colors.white24),
            const SizedBox(height: 15),
            // Add this new Row for the signup option
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?",
                    style: TextStyle(color: Colors.white70)),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignupScreen()),
                    );
                  },
                  child: const Text("Sign Up",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Text(text,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 20)),
      ],
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
      validator: (value) => value!.isEmpty ? "Please enter your $label" : null,
    );
  }

  Widget _buildPasswordField(
      TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white70),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
      validator: (value) => value!.isEmpty ? "Please enter your $label" : null,
    );
  }
}