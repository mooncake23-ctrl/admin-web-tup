import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ParkingHistoryScreen extends StatefulWidget {
  @override
  _ParkingHistoryScreenState createState() => _ParkingHistoryScreenState();
}

class _ParkingHistoryScreenState extends State<ParkingHistoryScreen> {
  List<dynamic> parkingHistory = [];
  List<dynamic> filteredHistory = [];
  bool isLoading = true;
  final Color _primaryColor = Color(0xFF71BFDC);
  final Color _secondaryColor = Color(0xFFEFEAEA);
  final Color _cardColor = Colors.white;
  final Color _textColor = Color(0xFF171616);
  late IO.Socket socket;
  TextEditingController _searchController = TextEditingController();

  // Filter and sort options
  String _selectedStatus = 'all';
  String _selectedSort = 'latest';
  String _limit = '10';

  @override
  void initState() {
    super.initState();
    fetchParkingHistory();
    _initSocket();
    _searchController.addListener(_filterHistory);
  }

  @override
  void dispose() {
    socket.disconnect();
    _searchController.dispose();
    super.dispose();
  }

  void _filterHistory() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredHistory = parkingHistory.where((history) {
        final name = history['name']?.toString().toLowerCase() ?? '';
        final slot = history['slotname']?.toString().toLowerCase() ?? '';
        final rfid = history['rfid']?.toString().toLowerCase() ?? '';
        return name.contains(query) || slot.contains(query) || rfid.contains(query);
      }).toList();
    });
  }

  void _initSocket() {
    try {
      socket = IO.io('https://appfinity.vercel.app', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
      });

      socket.onConnect((_) {
        print('Socket connected');
        socket.on('parking_update', (data) {
          print('Received parking update: $data');
          fetchParkingHistory();
        });

        socket.on('history_update', (data) {
          print('Received history update: $data');
          setState(() {
            final index = parkingHistory.indexWhere((item) => item['id'] == data['id']);
            if (index != -1) {
              parkingHistory[index] = data;
            } else {
              parkingHistory.insert(0, data);
              if (parkingHistory.length > int.parse(_limit)) {
                parkingHistory.removeLast();
              }
            }
            _filterHistory();
          });
        });
      });

      socket.onDisconnect((_) => print('Socket disconnected'));
      socket.onError((err) => print('Socket error: $err'));
    } catch (e) {
      print('Socket initialization error: $e');
    }
  }

  Future<void> fetchParkingHistory() async {
    try {
      setState(() => isLoading = true);

      final params = {
        if (_selectedStatus != 'all') 'status': _selectedStatus,
        'sort': _selectedSort,
        'limit': _limit,
      };

      final uri = Uri.https(
        'appfinity.vercel.app',
        '/parking-history',
        params,
      );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          parkingHistory = data.map((item) {
            // Convert status to entry/exit terminology
            if (item['status'] == 'active') {
              item['display_status'] = 'entry';
            } if (_selectedStatus == 'exit')
            {
              item['display_status'] = 'exit';
            }
            return item;
          }).toList();
          filteredHistory = parkingHistory;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load parking history: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteParkingHistory(String id) async {
    try {
      setState(() => isLoading = true);

      final response = await http.delete(
        Uri.https('appfinity.vercel.app', '/parking-history/delete/id/$id'),
      );

      if (response.statusCode == 200) {
        setState(() {
          parkingHistory.removeWhere((item) => item['id'].toString() == id);
          filteredHistory.removeWhere((item) => item['id'].toString() == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Record deleted successfully')),
        );
      } else {
        throw Exception('Failed to delete record: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[100],
          title: Text('Confirm Delete', style: TextStyle(color: Colors.black)),
          content: Text('Are you sure you want to delete this parking record?',
              style: TextStyle(color: Colors.black)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _primaryColor)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteParkingHistory(id);
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> handleParkingEntry(String rfid, String slotName) async {
    try {
      final entryResponse = await http.post(
        Uri.https('appfinity.vercel.app', '/update_slot_for_entry/$rfid'),
      );

      if (entryResponse.statusCode == 200) {
        final responseData = json.decode(entryResponse.body);

        await _createParkingHistory({
          'rfid': rfid,
          'slotname': slotName,
          'status': 'active',
          'display_status': 'entry',
          'info': 'User entered parking slot',
          'entry_time': DateTime.now().toIso8601String(),
        });

        socket.emit('parking_event', {
          'type': 'entry',
          'rfid': rfid,
          'slotName': slotName,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Parking entry recorded successfully')),
        );
      } else {
        throw Exception('Failed to update slot status: ${entryResponse.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Entry Error: ${e.toString()}')),
      );
    }
  }

  Future<void> handleParkingExit(String rfid) async {
    try {
      final exitResponse = await http.post(
        Uri.https('appfinity.vercel.app', '/update_slot_for_exit/$rfid'),
      );

      if (exitResponse.statusCode == 200) {
        final responseData = json.decode(exitResponse.body);
        final slotName = responseData['slotname'];

        final activeRecords = parkingHistory.where(
                (record) => record['rfid'] == rfid && record['status'] == 'active'
        ).toList();

        if (activeRecords.isNotEmpty) {
          final mostRecentRecord = activeRecords.last;

          await _createParkingHistory({
            'rfid': mostRecentRecord['rfid'],
            'slotname': slotName,
            'status': 'completed',
            'display_status': 'exit',
            'info': 'User exited parking slot',
            'entry_time': mostRecentRecord['entry_time'],
            'exit_time': DateTime.now().toIso8601String(),
          });

          socket.emit('parking_event', {
            'type': 'exit',
            'rfid': rfid,
            'slotName': slotName,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Parking exit recorded successfully')),
          );
        } else {
          throw Exception('No active parking found for RFID: $rfid');
        }
      } else {
        throw Exception('Failed to update slot status: ${exitResponse.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exit Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _createParkingHistory(Map<String, dynamic> historyData) async {
    try {
      final historyResponse = await http.post(
        Uri.https('appfinity.vercel.app', '/parking-history/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(historyData),
      );

      if (historyResponse.statusCode != 200) {
        throw Exception('Failed to add parking history');
      }
    } catch (e) {
      print('Error creating parking history: $e');
    }
  }

  Future<void> _showUserHistory(String rfid) async {
    try {
      setState(() => isLoading = true);

      final response = await http.get(
        Uri.https('appfinity.vercel.app', '/parking-history/user/$rfid'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> userHistory = json.decode(response.body);
        _showUserHistoryDialog(userHistory);
      } else {
        throw Exception('Failed to load user history: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showUserHistoryDialog(List<dynamic> userHistory) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[100],
          title: Text('User Parking History', style: TextStyle(color: Colors.black)),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: userHistory.length,
              itemBuilder: (context, index) {
                final history = userHistory[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 4.0),
                  color: Colors.white,
                  child: ListTile(
                    title: Text('Slot: ${history['slotname'] ?? '-'}',
                        style: TextStyle(color: Colors.black)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Type: ${history['display_status'] ?? history['status'] ?? '-'}',
                          style: TextStyle(
                            color: history['status'] == 'active'
                                ? Colors.green
                                : history['status'] == 'completed'
                                ? Colors.blue
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (history['entry_time'] != null)
                          Text('Entry: ${_formatTimestamp(history['entry_time'])}',
                              style: TextStyle(color: Colors.black)),
                        if (history['exit_time'] != null)
                          Text('Exit: ${_formatTimestamp(history['exit_time'])}',
                              style: TextStyle(color: Colors.black)),
                        if (history['entry_time'] != null && history['exit_time'] != null)
                          Text('Duration: ${_calculateDuration(history['entry_time'], history['exit_time'])}',
                              style: TextStyle(color: Colors.black)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: _primaryColor)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _secondaryColor,
      appBar: AppBar(
        title: Text('Parking History'),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchParkingHistory,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : parkingHistory.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 50, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No parking history available',
              style: TextStyle(fontSize: 18, color: _textColor),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        color: _primaryColor,
        onRefresh: fetchParkingHistory,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Search by Email Or Slot',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: _primaryColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: _primaryColor, width: 2.0),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${filteredHistory.length} records',
                    style: TextStyle(color: _textColor),
                  ),
                  Chip(
                    label: Text(
                        _selectedStatus == 'all' ? 'All' :
                        _selectedStatus == 'active' ? 'Entry' : 'Exit',
                        style: TextStyle(color: Colors.black)),
                    backgroundColor: _primaryColor,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredHistory.length,
                itemBuilder: (context, index) {
                  final history = filteredHistory[index];
                  return Card(
                    color: _cardColor,
                    margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    elevation: 4,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _primaryColor,
                        child: Icon(Icons.person, color: Colors.black),
                      ),
                      title: Text(
                        history['name'] ?? 'Unknown',
                        style: TextStyle(color: Colors.black),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Slot: ${history['slotname'] ?? '-'}',
                            style: TextStyle(color: Colors.black),
                          ),
                          Text(
                            'Type: ${history['display_status'] ?? history['status'] ?? '-'}',
                            style: TextStyle(
                              color: history['status'] == 'active'
                                  ? Colors.green
                                  : history['status'] == 'completed'
                                  ? Colors.blue
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (history['entry_time'] != null && history['exit_time'] != null)
                            Text(
                              'Duration: ${_calculateDuration(history['entry_time'], history['exit_time'])}',
                              style: TextStyle(color: Colors.black),
                            ),
                          if (history['timestamp'] != null)
                            Text(
                              'Time: ${_formatTimestamp(history['timestamp'])}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.history, color: _primaryColor),
                            onPressed: () {
                              if (history['rfid'] != null) {
                                _showUserHistory(history['rfid']);
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(history['id'].toString()),
                          ),
                        ],
                      ),
                      onTap: () {
                        _showHistoryDetails(history);
                      },
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

  String _calculateDuration(String? entryTime, String? exitTime) {
    if (entryTime == null || exitTime == null) return 'N/A';
    try {
      final entryDate = DateTime.parse(entryTime);
      final exitDate = DateTime.parse(exitTime);
      final duration = exitDate.difference(entryDate);
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      String normalizedTimestamp = timestamp;
      if (!normalizedTimestamp.endsWith('Z')) {
        normalizedTimestamp += 'Z';
      }

      DateTime dateTime = DateTime.parse(normalizedTimestamp).toLocal();

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
          '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error formatting timestamp "$timestamp": $e');
      return timestamp;
    }
  }

  void _showHistoryDetails(Map<String, dynamic> history) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[100],
          title: Text('Parking Details', style: TextStyle(color: Colors.black)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Name', history['name'] ?? 'Unknown'),
                _buildDetailRow('Slot', history['slotname'] ?? '-'),
                _buildDetailRow('Type', history['display_status'] ?? history['status'] ?? '-'),
                _buildDetailRow('Info', history['info'] ?? '-'),
                if (history['entry_time'] != null)
                  _buildDetailRow('Entry Time', _formatTimestamp(history['entry_time'])),
                if (history['exit_time'] != null)
                  _buildDetailRow('Exit Time', _formatTimestamp(history['exit_time'])),
                if (history['entry_time'] != null && history['exit_time'] != null)
                  _buildDetailRow('Duration', _calculateDuration(history['entry_time'], history['exit_time'])),
                _buildDetailRow('Timestamp', _formatTimestamp(history['timestamp'])),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: _primaryColor)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmDelete(history['id'].toString());
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[100],
          title: Text('Filters', style: TextStyle(color: Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(labelText: 'Status', labelStyle: TextStyle(color: Colors.black)),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('All', style: TextStyle(color: Colors.black)),
                  ),
                  DropdownMenuItem(
                    value: 'active',
                    child: Text('Entry', style: TextStyle(color: Colors.black)),
                  ),
                  DropdownMenuItem(
                    value: 'exit', // renamed from 'completed'
                    child: Text('Exit', style: TextStyle(color: Colors.black)),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value!;
                  });
                  Navigator.pop(context);
                  fetchParkingHistory();
                },
              ),

              DropdownButtonFormField<String>(
                value: _selectedSort,
                decoration: InputDecoration(
                  labelText: 'Sort by',
                  labelStyle: TextStyle(color: Colors.black),
                  filled: true,
                  fillColor: Colors.white, // Light background color
                  border: OutlineInputBorder(), // Optional: makes it more defined
                ),
                dropdownColor: Colors.white, // Dropdown background color
                style: TextStyle(color: Colors.black), // Dropdown text color
                iconEnabledColor: Colors.black, // Dropdown arrow icon color
                items: [
                  DropdownMenuItem(
                    value: 'latest',
                    child: Text('Latest', style: TextStyle(color: Colors.black)),
                  ),
                  DropdownMenuItem(
                    value: 'oldest',
                    child: Text('Oldest', style: TextStyle(color: Colors.black)),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSort = value!;
                  });
                  Navigator.pop(context);
                  fetchParkingHistory();
                },
              ),

              TextFormField(
                initialValue: _limit,
                decoration: InputDecoration(labelText: 'Limit', labelStyle: TextStyle(color: Colors.black)),
                style: TextStyle(color: Colors.black),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _limit = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                fetchParkingHistory();
              },
              child: Text('Apply Filters', style: TextStyle(color: _primaryColor)),
            ),
          ],
        );
      },
    );
  }
}