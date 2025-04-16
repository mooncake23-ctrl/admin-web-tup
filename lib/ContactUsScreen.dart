import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

class ContactUsScreen extends StatefulWidget {
  @override
  _ContactUsScreenState createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isSubmitting = false;
  bool _isFetchingMessages = false;
  String _statusMessage = '';
  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];
  List<dynamic> allMessages = [];
  Map<String, List<dynamic>> userMessages = {};
  final Color _primaryColor = Color(0xFF71BFDC);
  final Color _backgroundColor = Color(0xFFF8F6F6);
  String? _selectedUserName;

  @override
  void initState() {
    super.initState();
    fetchUsers();
    fetchAllMessages();
  }

  Future<void> fetchUsers() async {
    try {
      setState(() {
        _isSubmitting = true;
        _statusMessage = '';
      });

      final response = await http.get(
        Uri.parse('https://appfinity.vercel.app/admin'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Request failed with status: ${response.statusCode}');
      }

      final responseData = json.decode(response.body);

      setState(() {
        if (responseData is List) {
          users = responseData;
          filteredUsers = responseData;
        } else if (responseData is Map && responseData.containsKey('users')) {
          users = responseData['users'] is List ? responseData['users'] : [];
          filteredUsers = users;
        } else {
          users = [];
          filteredUsers = [];
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching users: ${e.toString().replaceAll('Exception: ', '')}';
      });
      developer.log('Error fetching users', error: e);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> fetchAllMessages() async {
    try {
      setState(() {
        _isFetchingMessages = true;
      });

      final response = await http.get(
        Uri.parse('https://appfinity.vercel.app/messages/all'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch messages: ${response.statusCode}');
      }

      final responseData = json.decode(response.body);

      setState(() {
        if (responseData is List) {
          allMessages = responseData;
        } else if (responseData is Map && responseData.containsKey('messages')) {
          allMessages = responseData['messages'] is List ? responseData['messages'] : [];
        } else {
          allMessages = [];
        }
      });
    } catch (e) {
      developer.log('Error fetching all messages', error: e);
    } finally {
      setState(() {
        _isFetchingMessages = false;
      });
    }
  }

  Future<void> fetchMessagesForUser(String name) async {
    try {
      setState(() {
        _isFetchingMessages = true;
        _selectedUserName = name;
        _statusMessage = '';
      });

      // First check if we have messages in allMessages
      final userMessagesList = allMessages.where((msg) =>
      msg['receiver'] == name || msg['sender'] == name).toList();

      if (userMessagesList.isNotEmpty) {
        setState(() {
          userMessages[name] = userMessagesList;
        });
        return;
      }

      // If not found in allMessages, try the specific endpoint
      final response = await http.get(
        Uri.parse('https://appfinity.vercel.app/messages/$name'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Request failed with status: ${response.statusCode}');
      }

      final responseData = json.decode(response.body);

      List<dynamic> messageList = [];
      if (responseData is List) {
        messageList = responseData;
      } else if (responseData is Map && responseData.containsKey('messages')) {
        messageList = responseData['messages'] is List ? responseData['messages'] : [];
      }

      setState(() {
        userMessages[name] = messageList;
      });
    } catch (e) {
      developer.log('Error fetching messages for $name', error: e);
      setState(() {
        _statusMessage = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
        userMessages[name] = [];
      });
    } finally {
      setState(() {
        _isFetchingMessages = false;
      });
    }
  }

  Future<void> sendMessageToUser(String userId, String message) async {
    try {
      setState(() {
        _isSubmitting = true;
      });

      final user = users.firstWhere(
            (u) => (u['id']?.toString() ?? u['_id']?.toString()) == userId,
        orElse: () => null,
      );

      if (user == null) {
        throw Exception('User not found');
      }

      final userName = user['name'] ?? 'Unknown';
      final userEmail = user['email'] ?? '';

      final Map<String, dynamic> requestBody = {
        'group': 'general',
        'message': message,
        'name': userName,
        'email': userEmail,
        'receiver': userName,
        'sender': 'Admin', // Changed from _nameController.text to 'Admin'
        'status': 'sent',
        'type': 'text',
      };

      final response = await http.post(
        Uri.parse('https://appfinity.vercel.app/messages/add'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to send message: ${response.statusCode}');
      }

      final responseData = json.decode(response.body);
      developer.log('Message sent response: $responseData');

      setState(() {
        _statusMessage = 'Message sent successfully!';
      });

      // Refresh messages after sending
      await fetchMessagesForUser(userName);
      await fetchAllMessages();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      });
      developer.log('Error sending message', error: e);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _filterUsers(String query) {
    setState(() {
      filteredUsers = users.where((user) {
        final name = user['name']?.toString().toLowerCase() ?? '';
        final email = user['email']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase()) ||
            email.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showUserMessagesDialog(Map<String, dynamic> user) {
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final userName = user['name']?.toString() ?? 'User';
    final userId = user['id']?.toString() ?? user['_id']?.toString() ?? '';

    // Fetch messages for this user
    fetchMessagesForUser(userName);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: _backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBar(
                      title: Text(
                        'Messages with $userName',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: _primaryColor,
                      elevation: 0,
                      centerTitle: true,
                      iconTheme: IconThemeData(color: Colors.white),
                    ),
                    if (_isFetchingMessages)
                      Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (userMessages[userName]?.isEmpty ?? true)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forum_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                              if (_statusMessage.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    _statusMessage,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.all(8),
                          itemCount: userMessages[userName]?.length ?? 0,
                          itemBuilder: (context, index) {
                            final message = userMessages[userName]![index];
                            final isCurrentUser = message['sender'] == 'Admin'; // Changed from _nameController.text to 'Admin'

                            return Container(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCurrentUser
                                    ? _primaryColor.withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        message['sender'] ?? 'Unknown',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentUser
                                              ? _primaryColor
                                              : Colors.black,
                                        ),
                                      ),
                                      Text(
                                        message['timestamp'] ?? message['createdAt'] ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    message['message'] ?? '',
                                    style: TextStyle(
                                      color: isCurrentUser
                                          ? Colors.black
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Form(
                        key: formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: messageController,
                              style: TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'New Message',
                                labelStyle: TextStyle(color: Colors.black),
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a message';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryColor,
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: _isSubmitting
                                        ? null
                                        : () async {
                                      if (formKey.currentState?.validate() ?? false) {
                                        await sendMessageToUser(
                                            userId,
                                            messageController.text
                                        );
                                        messageController.clear();
                                      }
                                    },
                                    child: _isSubmitting
                                        ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                        : Text(
                                      'SEND MESSAGE',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Contact Users',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search and Message Users',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Search for a user below to send them a message.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: Colors.black), // Set typed text color to black
                      decoration: InputDecoration(
                        labelText: 'Search Users',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: _filterUsers,
                    ),
                    SizedBox(height: 20),
                    if (_statusMessage.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _statusMessage.contains('Error') || _statusMessage.contains('Failed')
                              ? Colors.red[100]
                              : Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _statusMessage.contains('Error') || _statusMessage.contains('Failed')
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              color: _statusMessage.contains('Error') || _statusMessage.contains('Failed')
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _statusMessage,
                                style: TextStyle(
                                  color: _statusMessage.contains('Error') || _statusMessage.contains('Failed')
                                      ? Colors.red[800]
                                      : Colors.green[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Users (${filteredUsers.length} found)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            SizedBox(height: 10),
            if (filteredUsers.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 50, color: Colors.grey[400]),
                    SizedBox(height: 10),
                    Text(
                      'No users found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: Colors.white,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return InkWell(
                      onTap: () => _showUserMessagesDialog(user),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            user['name']?.toString().substring(0, 1) ?? '?',
                            style: TextStyle(color: _primaryColor),
                          ),
                          backgroundColor: _primaryColor.withOpacity(0.2),
                        ),
                        title: Text(
                          user['name']?.toString() ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          user['email']?.toString() ?? 'No email',
                          style: TextStyle(color: Colors.black54),
                        ),
                        trailing: Icon(Icons.message, color: _primaryColor),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}