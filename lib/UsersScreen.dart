import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'UserDetailScreen.dart';

class UsersScreen extends StatefulWidget {
  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsersAndProfiles();
  }

  Future<void> _fetchUsersAndProfiles() async {
    setState(() => isLoading = true);
    try {
      final usersResponse = await http.get(Uri.parse('https://appfinity.vercel.app/users'));

      if (usersResponse.statusCode == 200) {
        final responseData = jsonDecode(usersResponse.body);

        // Handle both cases where response might be a List or a Map
        List<dynamic> usersList = [];
        if (responseData is List) {
          usersList = responseData;
        } else if (responseData is Map) {
          // Check if there's a 'users' or 'data' field that contains the list
          if (responseData.containsKey('users')) {
            usersList = responseData['users'] is List ? responseData['users'] : [];
          } else if (responseData.containsKey('data')) {
            usersList = responseData['data'] is List ? responseData['data'] : [];
          } else {
            // If it's a Map but doesn't contain expected fields, use its values
            usersList = responseData.values.toList();
          }
        }

        for (var user in usersList) {
          if (user is! Map) continue; // Skip if user isn't a Map

          final profileResponse = await http.get(
            Uri.parse('https://appfinity.vercel.app/profile/${Uri.encodeComponent(user['name'] ?? '')}'),
          );

          if (profileResponse.statusCode == 200) {
            final profileData = jsonDecode(profileResponse.body);
            user['profile'] = profileData;
          } else {
            user['profile'] = null;
          }
        }

        setState(() {
          users = usersList;
          filteredUsers = usersList;
        });
      } else {
        _showError('Failed to fetch users (Status: ${usersResponse.statusCode})');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    }

    setState(() => isLoading = false);
  }

  void _filterUsers(String query) {
    setState(() {
      filteredUsers = users.where((user) {
        final name = user['name']?.toString().toLowerCase() ?? '';
        final rfid = user['rfid']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase()) ||
            rfid.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users List', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF71BFDC),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0F2F3), Color(0xFFD9D8DC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Search User',
                  labelStyle: TextStyle(color: Colors.black54), // Darker label
                  prefixIcon: Icon(Icons.search, color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
                style: TextStyle(color: Colors.black), // Black text for input
                onChanged: _filterUsers,
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : filteredUsers.isEmpty
                  ? Center(
                child: Text(
                  'No users found.',
                  style: TextStyle(color: Colors.black), // Black text
                ),
              )
                  : RefreshIndicator(
                onRefresh: _fetchUsersAndProfiles,
                child: ListView.builder(
                  padding: EdgeInsets.all(10),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final profile = user['profile'] ?? {};
                    final userName = user['name'] ?? 'Unnamed';
                    final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

                    return Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 6,
                      child: ListTile(
                        onTap: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  UserDetailScreen(user: user),
                            ),
                          );
                          if (updated == true) {
                            _fetchUsersAndProfiles();
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: Color(0xFF71BFDC).withOpacity(0.7),
                          backgroundImage: profile['image'] != null
                              ? NetworkImage(profile['image'])
                              : null,
                          child: profile['image'] == null
                              ? Text(firstLetter,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ))
                              : null,
                        ),
                        title: Text(
                          userName,
                          style: TextStyle(
                            color: Colors.black, // Black text for name
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'RFID: ${user['rfid'] ?? "N/A"}',
                          style: TextStyle(color: Colors.black87), // Dark text
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.black54, // Darker icon
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}