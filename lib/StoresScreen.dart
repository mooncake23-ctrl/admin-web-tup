import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StoresScreen extends StatefulWidget {
  @override
  _StoresScreenState createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  List<Map<String, dynamic>> slots = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];
  bool isLoading = true;
  int? selectedSlotIndex;
  final String baseUrl = 'https://appfinity.vercel.app/stores';
  final String usersUrl = 'https://appfinity.vercel.app/users';
  final String updateAssignedSlotUrl = 'https://appfinity.vercel.app/users/update_assignedslot';

  // Color palette
  final Color _primaryColor = Color(0xFF71BFDC);
  final Color _secondaryColor = Color(0xFFFFFFFE);
  final Color _accentColor = Color(0xFFF3EFEF);
  final Color _textColor = Color(0xFF5D4037);

  @override
  void initState() {
    super.initState();
    _fetchSlots();
    _fetchUsers();
  }

  Future<void> _fetchSlots() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(baseUrl));
      print("Slots API Response: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data[0] is Map<String, dynamic>) {
          final storeData = data[0] as Map<String, dynamic>;
          List<Map<String, dynamic>> extractedSlots = [];

          storeData.forEach((key, value) {
            if (key.startsWith("slot") && value != null) {
              extractedSlots.add({
                'slotNumber': int.parse(key.replaceAll("slot", "")),
                'occupiedBy': value == "available" ? null : value,
              });
            }
          });

          extractedSlots.sort((a, b) => a['slotNumber'].compareTo(b['slotNumber']));

          setState(() {
            slots = extractedSlots;
            isLoading = false;
          });
        } else {
          setState(() {
            slots = [];
            isLoading = false;
          });
          _showErrorDialog("No data found", "No valid store data is available.");
        }
      } else {
        setState(() => isLoading = false);
        _showErrorDialog("Error ${response.statusCode}", "Failed to fetch slots.");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog("Exception", e.toString());
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await http.get(Uri.parse(usersUrl));
      print("Users API Response: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData.containsKey('users')) {
          final List<dynamic> userList = responseData['users'];
          setState(() {
            users = userList.map((user) => user as Map<String, dynamic>).toList();
            filteredUsers = List.from(users);
          });
        }
      }
    } catch (e) {
      print("Error fetching users: $e");
    }
  }

  void _selectSlot(int index) {
    setState(() {
      selectedSlotIndex = index;
    });
    _showUserSelectionSheet();
  }

  void _showUserSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: _secondaryColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: UserSelectionSheet(
            users: filteredUsers,
            onSearchChanged: (query) {
              setState(() {
                filteredUsers = users
                    .where((user) => user['name']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()))
                    .toList();
              });
            },
            onUserSelected: (user) async {
              Navigator.pop(context);
              if (selectedSlotIndex != null) {
                await _assignUserToSlot(user, selectedSlotIndex!);
              }
            },
            primaryColor: _primaryColor,
            secondaryColor: _secondaryColor,
            textColor: _textColor,
          ),
        );
      },
    );
  }

  Future<void> _assignUserToSlot(Map<String, dynamic> user, int slotIndex) async {
    try {
      await _freeUserCurrentSlot(user['name']);
      await _freeSlotCurrentUser(slotIndex);
      await _updateSlot(slotIndex, user['name']);
      await _updateUserAssignedSlot(user['name'], 'slot${slots[slotIndex]['slotNumber']}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assigned ${user['name']} to slot ${slots[slotIndex]['slotNumber']}'),
          backgroundColor: _primaryColor,
        ),
      );
    } catch (e) {
      _showErrorDialog("Error", "Failed to assign user to slot: $e");
    }
  }

  Future<void> _unassignUserFromSlot(int slotIndex) async {
    try {
      final currentUser = slots[slotIndex]['occupiedBy'];

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Slot is already empty'),
            backgroundColor: _primaryColor,
          ),
        );
        return;
      }

      bool confirm = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Confirm Unassign'),
            content: Text('Are you sure you want to unassign $currentUser from slot ${slots[slotIndex]['slotNumber']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Unassign', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      await _updateSlot(slotIndex, null);
      await _updateUserAssignedSlot(currentUser, null);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unassigned $currentUser from slot ${slots[slotIndex]['slotNumber']}'),
          backgroundColor: _primaryColor,
        ),
      );
    } catch (e) {
      _showErrorDialog("Error", "Failed to unassign user: $e");
    }
  }

  Future<void> _freeUserCurrentSlot(String username) async {
    try {
      for (int i = 0; i < slots.length; i++) {
        if (slots[i]['occupiedBy'] == username) {
          await _updateSlot(i, null);
        }
      }
    } catch (e) {
      print("Error freeing user's current slot: $e");
    }
  }

  Future<void> _freeSlotCurrentUser(int slotIndex) async {
    try {
      final currentUser = slots[slotIndex]['occupiedBy'];
      if (currentUser != null) {
        await _updateUserAssignedSlot(currentUser, null);
      }
    } catch (e) {
      print("Error freeing slot's current user: $e");
    }
  }

  Future<void> _updateSlot(int index, String? user) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update-slot'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'new_value': user ?? "available",
          'slot': "slot${slots[index]['slotNumber']}",
          'unique_id': "12345",
        }),
      );

      if (response.statusCode == 200) {
        _fetchSlots();
      } else {
        throw Exception("Failed to update slot");
      }
    } catch (e) {
      throw Exception("Failed to update slot: $e");
    }
  }

  Future<void> _updateUserAssignedSlot(String username, String? slot) async {
    try {
      final response = await http.put(
        Uri.parse(updateAssignedSlotUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'assignedslot': slot ?? "available",
          'name': username,
        }),
      );

      if (response.statusCode == 200) {
        _fetchUsers();
      } else {
        throw Exception("Failed to update user's assigned slot");
      }
    } catch (e) {
      throw Exception("Failed to update user's assigned slot: $e");
    }
  }

  Future<void> _showErrorDialog(String title, String message) async {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: _secondaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  message,
                  style: TextStyle(color: _textColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _accentColor,
      appBar: AppBar(
        title: Text(
          'Manage Parking Slots',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: _primaryColor,
        ),
      )
          : slots.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_parking,
              size: 50,
              color: _accentColor,
            ),
            SizedBox(height: 16),
            Text(
              'No parking slots available',
              style: TextStyle(
                fontSize: 18,
                color: _textColor,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        color: _primaryColor,
        onRefresh: _fetchSlots,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  _showSlotSelectionDialog();
                },
                child: Text(
                  'Assign User to Slot',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: slots.length,
                itemBuilder: (context, index) {
                  final isOccupied = slots[index]['occupiedBy'] != null;
                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                    color: isOccupied ? _secondaryColor : Colors.white,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => _selectSlot(index),
                      onLongPress: isOccupied ? () => _unassignUserFromSlot(index) : null,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Slot ${slots[index]['slotNumber']}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isOccupied
                                        ? _primaryColor.withOpacity(0.2)
                                        : Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isOccupied ? 'Occupied' : 'Available',
                                    style: TextStyle(
                                      color: isOccupied
                                          ? _primaryColor
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            if (isOccupied) ...[
                              Text(
                                'Occupied by: ${slots[index]['occupiedBy']}',
                                style: TextStyle(color: _textColor),
                              ),
                              SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _unassignUserFromSlot(index),
                                  child: Text(
                                    'Unassign',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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

  void _showSlotSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: _secondaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select a Slot',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  height: 300,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: slots.length,
                    itemBuilder: (context, index) {
                      final isOccupied = slots[index]['occupiedBy'] != null;
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isOccupied ? _secondaryColor : Colors.white,
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          leading: CircleAvatar(
                            backgroundColor: _primaryColor.withOpacity(0.2),
                            child: Icon(Icons.local_parking,
                                color: _primaryColor),
                          ),
                          title: Text(
                            'Slot ${slots[index]['slotNumber']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          subtitle: Text(
                            isOccupied
                                ? 'Occupied by: ${slots[index]['occupiedBy']}'
                                : 'Available',
                            style: TextStyle(color: _textColor),
                          ),
                          trailing: Icon(Icons.arrow_forward,
                              color: _primaryColor),
                          onTap: () {
                            Navigator.pop(context);
                            _selectSlot(index);
                          },
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: _textColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class UserSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final Function(String) onSearchChanged;
  final Function(Map<String, dynamic>) onUserSelected;
  final Color primaryColor;
  final Color secondaryColor;
  final Color textColor;

  UserSelectionSheet({
    required this.users,
    required this.onSearchChanged,
    required this.onUserSelected,
    required this.primaryColor,
    required this.secondaryColor,
    required this.textColor,
  });

  @override
  _UserSelectionSheetState createState() => _UserSelectionSheetState();
}

class _UserSelectionSheetState extends State<UserSelectionSheet> {
  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Assign User to Slot',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: widget.primaryColor,
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Search for user...',
              prefixIcon: Icon(Icons.search, color: widget.primaryColor),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            onChanged: widget.onSearchChanged,
          ),
          SizedBox(height: 16),
          Expanded(
            child: widget.users.isEmpty
                ? Center(
              child: Text(
                "No users found",
                style: TextStyle(color: widget.textColor),
              ),
            )
                : ListView.builder(
              itemCount: widget.users.length,
              itemBuilder: (context, index) {
                final user = widget.users[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: widget.secondaryColor,
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor:
                      widget.primaryColor.withOpacity(0.2),
                      child: Icon(Icons.person,
                          color: widget.primaryColor),
                    ),
                    title: Text(
                      user['name'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.textColor,
                      ),
                    ),
                    subtitle: Text(
                      'Role: ${user['role'] ?? 'Unknown'}',
                      style: TextStyle(color: widget.textColor),
                    ),
                    trailing: Icon(Icons.arrow_forward,
                        color: widget.primaryColor),
                    onTap: () => widget.onUserSelected(user),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: widget.textColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }
}