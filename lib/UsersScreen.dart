import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'UserDetailScreen.dart';
import 'dart:async';

class UsersScreen extends StatefulWidget {
  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  bool _isDisposed = false;
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    _fetchUsersWithCache();
  }

  @override
  void dispose() {
    _isDisposed = true;
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsersWithCache() async {
    // Don't fetch if data is fresh (within last 30 seconds)
    if (_lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < Duration(seconds: 30)) {
      if (!_isDisposed) setState(() => isLoading = false);
      return;
    }

    await _fetchUsersAndProfiles();
  }

  Future<void> _fetchUsersAndProfiles() async {
    if (!_isDisposed) setState(() => isLoading = true);

    try {
      // 1. First fetch users with a timeout
      final usersResponse = await http.get(
          Uri.parse('https://appfinity.vercel.app/users')
      ).timeout(Duration(seconds: 15));

      if (usersResponse.statusCode == 200) {
        final responseData = jsonDecode(usersResponse.body);
        List<dynamic> usersList = [];

        // Handle response data parsing
        if (responseData is List) {
          usersList = responseData;
        } else if (responseData is Map) {
          if (responseData.containsKey('users')) {
            usersList = responseData['users'] is List ? responseData['users'] : [];
          } else if (responseData.containsKey('data')) {
            usersList = responseData['data'] is List ? responseData['data'] : [];
          } else {
            usersList = responseData.values.toList();
          }
        }

        // Filter out admin users
        usersList = usersList.where((user) {
          return user is Map && (user['role']?.toString().toLowerCase() != 'admin');
        }).toList();

        // 2. Optimize profile fetching - do it in parallel with rate limiting
        await _fetchProfilesInParallel(usersList);

        if (!_isDisposed) {
          setState(() {
            users = usersList;
            filteredUsers = usersList;
            _lastFetchTime = DateTime.now();
          });
        }
      } else {
        _showError('Failed to fetch users (Status: ${usersResponse.statusCode})');
      }
    } on http.ClientException catch (e) {
      _showError('Network error: ${e.message}');
    } on TimeoutException {
      _showError('Request timed out. Please try again.');
    } catch (e) {
      _showError('An error occurred: ${e.toString()}');
    }

    if (!_isDisposed) setState(() => isLoading = false);
  }

  Future<void> _fetchProfilesInParallel(List<dynamic> usersList) async {
    // Rate limiting - process 5 at a time to avoid overwhelming the server
    const batchSize = 5;
    for (var i = 0; i < usersList.length; i += batchSize) {
      final batch = usersList.sublist(
          i,
          i + batchSize > usersList.length ? usersList.length : i + batchSize
      );

      await Future.wait(batch.map((user) async {
        if (user is! Map) return;

        try {
          final profileResponse = await http.get(
              Uri.parse('https://appfinity.vercel.app/profile/${Uri.encodeComponent(user['name'] ?? '')}')
          ).timeout(Duration(seconds: 10));

          if (profileResponse.statusCode == 200) {
            user['profile'] = jsonDecode(profileResponse.body);
          } else {
            user['profile'] = null;
          }
        } catch (e) {
          // Silently fail for individual profile fetches
          user['profile'] = null;
        }
      }));
    }
  }

  void _filterUsers(String query) {
    if (!_isDisposed) {
      setState(() {
        filteredUsers = users.where((user) {
          final name = user['name']?.toString().toLowerCase() ?? '';
          final rfid = user['rfid']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) ||
              rfid.contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  void _showError(String message) {
    if (!_isDisposed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
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
                  labelStyle: TextStyle(color: Colors.black54),
                  prefixIcon: Icon(Icons.search, color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
                style: TextStyle(color: Colors.black),
                onChanged: _filterUsers,
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading users...',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              )
                  : filteredUsers.isEmpty
                  ? Center(
                child: Text(
                  'No users found.',
                  style: TextStyle(color: Colors.black),
                ),
              )
                  : RefreshIndicator(
                onRefresh: _fetchUsersWithCache,
                child: ListView.builder(
                  padding: EdgeInsets.all(10),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final profile = user['profile'] ?? {};
                    final userName = user['name'] ?? 'Unnamed';
                    final firstLetter = userName.isNotEmpty
                        ? userName[0].toUpperCase()
                        : '?';

                    return Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 6,
                      margin: EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
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
                            _fetchUsersWithCache();
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor:
                          Color(0xFF71BFDC).withOpacity(0.7),
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
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'RFID: ${user['rfid'] ?? "N/A"}',
                          style: TextStyle(color: Colors.black87),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.black54,
                          size: 16,
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