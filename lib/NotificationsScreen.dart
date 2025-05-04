import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:math';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List notifications = [];
  bool isLoading = true;
  final Color _primaryColor = Color(0xFF71BFDC);
  final Color _backgroundColor = Color(0xFFF6F6F5);
  final Color _cardColor = Colors.white;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  String _generateUniqueId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
      Iterable.generate(
        6,
            (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime.toLocal());

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} sec ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  String formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return 'Just now';

      DateTime? parsedDateTime;

      // If it's already a DateTime object
      if (timestamp is DateTime) {
        parsedDateTime = timestamp;
      }
      // Handle string timestamps
      else if (timestamp is String) {
        // First try parsing HTTP date format (e.g. "Wed, 16 Apr 2025 15:48:31 GMT")
        try {
          parsedDateTime = _parseHttpDate(timestamp);
        } catch (e) {
          debugPrint('Failed to parse HTTP date: $timestamp');
        }

        // Try ISO format if HTTP format failed
        if (parsedDateTime == null) {
          // Try parsing as UTC by adding 'Z' if not present
          String normalizedTimestamp = timestamp;
          if (!timestamp.endsWith('Z')) {
            normalizedTimestamp += 'Z';
          }
          parsedDateTime = DateTime.tryParse(normalizedTimestamp);
        }

        // Try SQL datetime format if still null
        if (parsedDateTime == null && timestamp.contains(' ')) {
          parsedDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(timestamp);
        }

        // Try milliseconds since epoch
        if (parsedDateTime == null) {
          final milliseconds = int.tryParse(timestamp);
          if (milliseconds != null) {
            parsedDateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
          }
        }

        if (parsedDateTime == null) {
          debugPrint('Failed to parse timestamp: $timestamp');
          parsedDateTime = DateTime.now();
        }
      }
      // Numeric timestamp
      else if (timestamp is int) {
        parsedDateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        debugPrint('Unknown timestamp type: ${timestamp.runtimeType}');
        parsedDateTime = DateTime.now();
      }

      // Ensure we're working with UTC before converting to local
      if (!parsedDateTime.isUtc) {
        parsedDateTime = DateTime.utc(
          parsedDateTime.year,
          parsedDateTime.month,
          parsedDateTime.day,
          parsedDateTime.hour,
          parsedDateTime.minute,
          parsedDateTime.second,
        );
      }

      return _formatDateTime(parsedDateTime.toLocal());
    } catch (e) {
      debugPrint('Error formatting timestamp: $e');
      return _formatDateTime(DateTime.now().toLocal());
    }
  }

  DateTime _parseHttpDate(String httpDate) {
    // Example format: "Wed, 16 Apr 2025 15:48:31 GMT"
    final months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
    };

    final parts = httpDate.split(' ');
    if (parts.length < 6) throw FormatException('Invalid HTTP date format');

    final day = int.parse(parts[1]);
    final month = months[parts[2]] ?? 1;
    final year = int.parse(parts[3]);
    final timeParts = parts[4].split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final second = int.parse(timeParts[2]);

    // Create as UTC time since HTTP dates are in GMT
    return DateTime.utc(year, month, day, hour, minute, second);
  }
  Future<void> fetchNotifications() async {
    try {
      setState(() => isLoading = true);
      final response = await http.get(Uri.parse('https://appfinity.vercel.app/notifications'));

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        if (responseData is List) {
          setState(() {
            notifications = responseData.map((item) {
              if (item is Map) {
                return {
                  'id': item['id'] ?? _generateUniqueId(),
                  'message': item['message'] ?? 'No message',
                  'sender': item['sender'] ?? 'System',
                  'status': item['status'] ?? 'active',
                  'timestamp': item['timestamp'] ?? DateTime.now().toIso8601String(),
                  'uniqueId': item['uniqueId'] ?? _generateUniqueId(),
                };
              } else if (item is List) {
                return {
                  'id': item.length > 0 ? item[0] : _generateUniqueId(),
                  'message': item.length > 4 ? item[4] : 'No message',
                  'sender': item.length > 2 ? item[2] : 'System',
                  'status': item.length > 3 ? item[3] : 'active',
                  'timestamp': item.length > 5 ? item[5] : DateTime.now().toIso8601String(),
                  'uniqueId': item.length > 6 ? item[6] : _generateUniqueId(),
                };
              }
              return {
                'id': _generateUniqueId(),
                'message': 'No message',
                'sender': 'System',
                'status': 'active',
                'timestamp': DateTime.now().toIso8601String(),
                'uniqueId': _generateUniqueId(),
              };
            }).toList();
            isLoading = false;
          });
        } else {
          setState(() {
            notifications = [];
            isLoading = false;
          });
        }
      } else {
        setState(() {
          notifications = [];
          isLoading = false;
        });
        debugPrint('Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        notifications = [];
        isLoading = false;
      });
      debugPrint('Exception: $e');
    }
  }

  Widget buildNotificationItem(Map notification, int index) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: _cardColor,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 60,
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ), // ← this was missing!
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['message'],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        notification['sender'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        formatTimestamp(notification['timestamp']),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> addNotification(String message, String status) async {
    try {
      final uniqueId = _generateUniqueId();
      final response = await http.post(
        Uri.parse('https://appfinity.vercel.app/notifications/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': message,
          'role': 'admin',
          'status': status,
          'uniqueId': uniqueId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification added successfully!'),
            backgroundColor: _primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        fetchNotifications();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding notification!'),
          backgroundColor: Colors.red[300],
        ),
      );
    }
  }

  void showAddNotificationDialog() {
    final formKey = GlobalKey<FormState>();
    TextEditingController messageController = TextEditingController();
    String selectedStatus = "active";

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "New Notification",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: messageController,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: "Message",
                      labelStyle: TextStyle(color: Colors.black),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    style: TextStyle(color: Colors.black),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedStatus = newValue!;
                      });
                    },
                    items: ['active', 'new'].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: TextStyle(color: Colors.black)),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: "Status",
                      labelStyle: TextStyle(color: Colors.black54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            addNotification(
                                messageController.text,
                                selectedStatus
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: Text("Add", style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchNotifications,
          )
        ],
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: _primaryColor,
        ),
      )
          : notifications.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 50, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                showAddNotificationDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Add First Notification'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        color: _primaryColor,
        onRefresh: fetchNotifications,
        child: ListView.builder(
          physics: AlwaysScrollableScrollPhysics(),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            return buildNotificationItem(notifications[index], index);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddNotificationDialog,
        child: Icon(Icons.add, color: Colors.white, size: 30),
        backgroundColor: _primaryColor,
        elevation: 4,
      ),
    );
  }
}