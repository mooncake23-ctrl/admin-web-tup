import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart'; // Added for clipboard functionality
import 'EditUserScreen.dart';
import 'package:flutter/services.dart';

class UserDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  UserDetailScreen({required this.user});

  @override
  _UserDetailScreenState createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  Map<String, dynamic>? userProfile;
  bool isLoading = true;
  bool hasError = false;
  TextEditingController _nameController = TextEditingController();
  bool _isNameCorrect = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      String apiUrl = 'https://appfinity.vercel.app/profile';
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> userList = jsonDecode(response.body);
        final userMatch = userList.firstWhere(
              (user) =>
          user['name'].toString().toLowerCase() ==
              widget.user['name'].toString().toLowerCase(),
          orElse: () => null,
        );

        if (userMatch != null) {
          setState(() {
            userProfile = userMatch;
            isLoading = false;
          });
        } else {
          setState(() {
            hasError = true;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  Future<void> _deleteUser() async {
    try {
      // Delete the profile
      String deleteProfileUrl =
          'https://appfinity.vercel.app/profile/delete?name=${widget.user['name']}';
      final profileResponse = await http.delete(Uri.parse(deleteProfileUrl));

      if (profileResponse.statusCode == 200) {
        // Delete the user
        String deleteUserUrl = 'https://appfinity.vercel.app/users/delete';
        final userResponse = await http.delete(
          Uri.parse(deleteUserUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': widget.user['name']}),
        );

        if (userResponse.statusCode == 200) {
          // Successfully deleted both user and profile
          Navigator.pop(context, true);
        } else {
          _showErrorDialog('Failed to delete user');
        }
      } else {
        _showErrorDialog('Failed to delete profile');
      }
    } catch (e) {
      _showErrorDialog('Error: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _checkNameMatch() {
    setState(() {
      _isNameCorrect = _nameController.text.trim().toLowerCase() == widget.user['name'].toString().toLowerCase();
    });
  }

  // Function to copy RFID to clipboard
  Future<void> _copyRFIDToClipboard() async {
    final rfid = widget.user['rfid']?.toString().trim();

    if (rfid != null && rfid.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: rfid));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('RFID copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No RFID available to copy'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.user['name']} Details',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF71BFDC),
              Color(0xFF9676D6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: isLoading
              ? CircularProgressIndicator()
              : hasError
              ? Text(
            'Failed to load user profile',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          )
              : Card(
            color: Colors.white.withOpacity(0.9),
            margin: EdgeInsets.all(16.0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            elevation: 6,
            shadowColor: Color(0xFF42B5B5).withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow(
                      Icons.person, 'Full Name',
                      userProfile?['full_name'] ?? "N/A"),
                  _buildDetailRow(
                      Icons.badge, 'ID Number',
                      userProfile?['id_number'] ?? "N/A"),
                  _buildDetailRow(Icons.email, 'Email',
                      widget.user['email'] ?? "N/A"),
                  // Modified RFID row to include copy button
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.credit_card, color: Color(0xFF1AA6B8), size: 28),
                        SizedBox(width: 12),
                        Text(
                          'RFID:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1AA6B8)),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.user['rfid'] ?? "N/A",
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.content_copy, size: 20),
                          onPressed: _copyRFIDToClipboard,
                          tooltip: 'Copy RFID',
                        ),
                      ],
                    ),
                  ),
                  _buildDetailRow(
                      Icons.directions_car, 'Plate Number',
                      userProfile?['plate_number'] ?? "N/A"),
                  _buildDetailRow(
                      Icons.two_wheeler, 'Vehicle Type',
                      userProfile?['vehicle_type'] ?? "N/A"),
                  _buildDetailRow(
                      Icons.car_repair, 'Vehicle Model',
                      userProfile?['vehicle_model'] ?? "N/A"),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2CAFB3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      padding: EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                EditUserScreen(user: widget.user)),
                      ).then((updated) {
                        if (updated == true) {
                          Navigator.pop(context, true);
                        }
                      });
                    },
                    child: Text('Edit User',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 20),
                  // New confirmation before deleting
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Enter user name to confirm',
                      labelStyle: TextStyle(color: Colors.black),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _checkNameMatch(),
                    style: TextStyle(color: Colors.black), // Set the text color to black
                  ),

                  SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      padding: EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
                    ),
                    onPressed: _isNameCorrect ? _deleteUser : null,
                    child: Text('Delete User',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF1AA6B8), size: 28),
          SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1AA6B8)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}