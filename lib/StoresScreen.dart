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
  final String assignSlotUrl = 'https://appfinity.vercel.app/update_slot_for_entry';
  final String unassignSlotUrl = 'https://appfinity.vercel.app/update_slot_for_exit';
  final String updateAssignedSlotUrl = 'https://appfinity.vercel.app/update_user_slot';

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
      print("Slots API Response: ${response.statusCode} - ${response.body}");

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
        _showErrorDialog("Error ${response.statusCode}", "Failed to fetch slots. Server returned: ${response.body}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog("Exception", "Failed to fetch slots: ${e.toString()}");
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await http.get(Uri.parse(usersUrl));
      print("Users API Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData.containsKey('users')) {
          final List<dynamic> userList = responseData['users'];
          setState(() {
            users = userList.map((user) => user as Map<String, dynamic>).toList();
            filteredUsers = List.from(users);
          });
        }
      } else {
        print("Failed to fetch users: ${response.statusCode} - ${response.body}");
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
          child: Padding(
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
                  await _showRfidDialogForAssignment(user, selectedSlotIndex!);
                }
              },
              primaryColor: _primaryColor,
              secondaryColor: _secondaryColor,
              textColor: _textColor,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRfidDialogForAssignment(Map<String, dynamic> user, int slotIndex) async {
    final rfidController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Enter RFID for ${user['name']}'),
              content: TextField(
                controller: rfidController,
                decoration: InputDecoration(
                  hintText: 'Enter RFID tag',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (rfidController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter RFID')),
                      );
                      return;
                    }

                    setState(() => isSubmitting = true);
                    try {
                      await _assignUserToSlot(user, slotIndex, rfidController.text);
                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    } finally {
                      setState(() => isSubmitting = false);
                    }
                  },
                  child: isSubmitting
                      ? CircularProgressIndicator()
                      : Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _assignUserToSlot(Map<String, dynamic> user, int slotIndex, String rfid) async {
    setState(() => isLoading = true);
    try {
      // First free the user from any existing slot
      await _freeUserCurrentSlotByRfid(rfid);

      // Assign to new slot
      await _assignSlot(rfid, slots[slotIndex]['slotNumber']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assigned ${user['name']} to slot ${slots[slotIndex]['slotNumber']}'),
          backgroundColor: _primaryColor,
        ),
      );

      // Refresh data
      await _fetchSlots();
    } catch (e) {
      _showErrorDialog("Error", "Failed to assign user to slot: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _unassignUserFromSlot(int slotIndex) async {
    final rfidController = TextEditingController();
    bool isSubmitting = false;

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

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Unassign User from Slot'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Slot ${slots[slotIndex]['slotNumber']} is currently assigned to:'),
                  SizedBox(height: 8),
                  Text(currentUser, style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('Please scan the RFID tag to confirm unassignment:'),
                  SizedBox(height: 8),
                  TextField(
                    controller: rfidController,
                    decoration: InputDecoration(
                      hintText: 'Enter RFID tag',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (rfidController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter RFID')),
                      );
                      return;
                    }

                    setState(() => isSubmitting = true);
                    try {
                      await _unassignSlot(rfidController.text, slots[slotIndex]['slotNumber']);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Unassigned $currentUser from slot ${slots[slotIndex]['slotNumber']}'),
                          backgroundColor: _primaryColor,
                        ),
                      );
                      Navigator.pop(context);
                      await _fetchSlots();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    } finally {
                      setState(() => isSubmitting = false);
                    }
                  },
                  child: isSubmitting
                      ? CircularProgressIndicator()
                      : Text('Unassign', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _freeUserCurrentSlotByRfid(String rfid) async {
    try {
      final response = await http.post(
        Uri.parse(unassignSlotUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'rfid': rfid}),
      );

      print("Free Slot Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode != 200) {
        throw Exception("Failed to free user's current slot: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error freeing user's current slot: $e");
    }
  }

  Future<void> _assignSlot(String rfid, int slotNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$assignSlotUrl/$rfid'), // RFID in URL path
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'slot': 'slot$slotNumber', // Slot in request body
        }),
      );

      print("Assign Slot Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode != 200) {
        throw Exception("Failed to assign slot: ${response.body}");
      }
    } catch (e) {
      throw Exception("Assign slot error: $e");
    }
  }

  Future<void> _unassignSlot(String rfid, int slotNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$unassignSlotUrl/$rfid'), // RFID in URL path
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'slot': 'slot$slotNumber', // Slot in request body
        }),
      );

      print("Unassign Slot Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode != 200) {
        throw Exception("Failed to unassign slot: ${response.body}");
      }
    } catch (e) {
      throw Exception("Unassign slot error: $e");
    }
  }

  Future<void> _showErrorDialog(String title, String message) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _secondaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(color: _textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
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
            // REMOVED THE ELEVATED BUTTON FROM HERE
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
                      onLongPress: isOccupied
                          ? () => _unassignUserFromSlot(index)
                          : null,
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
                                  onPressed: () =>
                                      _unassignUserFromSlot(index),
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