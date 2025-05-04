import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class ProfilesScreen extends StatefulWidget {
  @override
  _ProfilesScreenState createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> with SingleTickerProviderStateMixin {
  List<dynamic> stores = [];
  List<dynamic> filteredStores = [];
  Map<String, dynamic>? selectedSlotDetails;
  String? selectedSlotNumber;
  bool isLoading = true;
  String? occupiedSlotUserInfo;

  // Modern color palette
  final Color backgroundColor = Color(0xFFF8FAFC);
  final Color primaryColor = Color(0xFF71BFDC);
  final Color secondaryColor = Color(0xFF003566);
  final Color accentColor = Color(0xFF8338EC);
  final Color availableColor = Color(0xFF4CAF50); // Softer Green
  final Color unavailableColor = Color(0xFFEF5350); // Softer Red
  final Color textColor = Color(0xFF1A1A1A);
  final Color lightTextColor = Color(0xFF7F8C8D);
  final Color cardColor = Colors.white;
  final Color dividerColor = Color(0xFFEDF2F7);

  late AnimationController _controller;
  late Animation<double> _animation;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _fetchStores();
    _startRealTimeUpdates();
  }

  void _startRealTimeUpdates() {
    _timer = Timer.periodic(Duration(seconds: 2), (timer) {
      _fetchStores();
    });
  }

  Future<void> _fetchStores() async {
    try {
      final response = await http.get(Uri.parse('https://appfinity.vercel.app/stores'));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data is List) {
          stores = data;
        } else {
          stores = [data];
        }
        _applyFilters();
      } else {
        throw Exception('Failed to load stores');
      }
    } catch (e) {
      print('Error fetching stores: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _applyFilters() {
    if (mounted) {
      setState(() {
        filteredStores = stores;
        if (!isLoading) {
          _controller.forward(from: 0);
        }
      });
    }
  }

  int _countSlots(Map<String, dynamic> store) {
    return store.keys.where((key) => key.startsWith('slot')).length;
  }

  List<String> _getSlotNumbers(Map<String, dynamic> store) {
    return store.keys
        .where((key) => key.startsWith('slot'))
        .map((key) => key.replaceAll('slot', ''))
        .toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  }

  int _availableSlotCount(Map<String, dynamic> store) {
    return store.entries
        .where((entry) => entry.key.startsWith('slot'))
        .where((entry) => entry.value == 'available')
        .length;
  }

  void _showSlotDetails(String slotNumber, dynamic slotData) {
    setState(() {
      selectedSlotNumber = slotNumber;
      selectedSlotDetails = slotData is Map<String, dynamic> ? slotData : null;
    });

    if (selectedSlotDetails != null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          margin: EdgeInsets.only(top: 50),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Slot $slotNumber',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 20),
              if (selectedSlotDetails!['name'] != null)
                _buildDetailRow(Icons.person_outline, selectedSlotDetails!['name']),
              if (selectedSlotDetails!['email'] != null)
                _buildDetailRow(Icons.email_outlined, selectedSlotDetails!['email']),
              if (selectedSlotDetails!['phone'] != null)
                _buildDetailRow(Icons.phone_iphone_outlined, selectedSlotDetails!['phone']),
              if (selectedSlotDetails!['time'] != null)
                _buildDetailRow(Icons.access_time_outlined, selectedSlotDetails!['time']),
              if (selectedSlotDetails!['date'] != null)
                _buildDetailRow(Icons.calendar_today_outlined, selectedSlotDetails!['date']),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String text) => Container(
    padding: EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: dividerColor,
          width: 1,
        ),
      ),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          color: secondaryColor,
          size: 22,
        ),
        SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  void _onSlotOccupied(String slotNumber, Map<String, dynamic> slotData) async {
    String userName = slotData['name'];

    try {
      final response = await http.get(
        Uri.parse('https://appfinity.vercel.app/profile/$userName'),
        headers: {'accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final profileList = json.decode(response.body);

        if (profileList is List && profileList.isNotEmpty) {
          final profileData = profileList[0];

          setState(() {
            occupiedSlotUserInfo =
            '👤 ${profileData['full_name'] ?? 'N/A'}\n'
                '🚗 ${profileData['vehicle_model'] ?? 'N/A'}\n'
                '🔢 ${profileData['plate_number'] ?? 'N/A'}';
          });
        } else {
          setState(() {
            occupiedSlotUserInfo = 'User info not found';
          });
        }
      } else {
        setState(() {
          occupiedSlotUserInfo = 'Failed to fetch user profile';
        });
      }
    } catch (e) {
      print('Error fetching profile: $e');
      setState(() {
        occupiedSlotUserInfo = 'Failed to load user info';
      });
    }

    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          occupiedSlotUserInfo = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          'Parking Slot Monitor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchStores,
          ),
        ],
      ),
      body: isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Loading parking data...',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: filteredStores.map((store) {
                final totalSlots = _countSlots(store);
                final availableCount = _availableSlotCount(store);
                final percentageAvailable = totalSlots > 0
                    ? (availableCount / totalSlots * 100).round()
                    : 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: cardColor,
                    shadowColor: Colors.black.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Parking Area ${stores.indexOf(store) + 1}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      percentageAvailable > 30
                                          ? availableColor.withOpacity(0.8)
                                          : unavailableColor.withOpacity(0.8),
                                      percentageAvailable > 30
                                          ? availableColor
                                          : unavailableColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$percentageAvailable% available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: totalSlots > 0 ? availableCount / totalSlots : 0,
                              backgroundColor: unavailableColor.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  percentageAvailable > 30 ? availableColor : unavailableColor),
                              minHeight: 10,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Available: ',
                                      style: TextStyle(
                                        color: lightTextColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '$availableCount',
                                      style: TextStyle(
                                        color: availableColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Total: ',
                                      style: TextStyle(
                                        color: lightTextColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '$totalSlots',
                                      style: TextStyle(
                                        color: secondaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1,
                            ),
                            itemCount: totalSlots,
                            itemBuilder: (context, index) {
                              final slotNumbers = _getSlotNumbers(store);
                              final slotNumber = slotNumbers[index];
                              final slotKey = 'slot$slotNumber';
                              final slotData = store[slotKey];
                              final isAvailable = slotData == 'available';

                              return GestureDetector(
                                onTap: () {
                                  if (!isAvailable && slotData is Map) {
                                    _onSlotOccupied(slotNumber, Map<String, dynamic>.from(slotData));
                                  }
                                  _showSlotDetails(slotNumber, Map<String, dynamic>.from(slotData));
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                isAvailable
                                                    ? availableColor.withOpacity(0.9)
                                                    : unavailableColor.withOpacity(0.9),
                                                isAvailable
                                                    ? availableColor
                                                    : unavailableColor,
                                              ],
                                            ),
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                              MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  slotNumber,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 24,
                                                    shadows: [
                                                      Shadow(
                                                        blurRadius: 4,
                                                        color: Colors.black.withOpacity(0.2),
                                                        offset: Offset(1, 1),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.2),
                                                    borderRadius:
                                                    BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    isAvailable
                                                        ? 'AVAILABLE'
                                                        : 'OCCUPIED',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (!isAvailable)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding: EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.3),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (occupiedSlotUserInfo != null)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                opacity: occupiedSlotUserInfo != null ? 1.0 : 0.0,
                duration: Duration(milliseconds: 300),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          secondaryColor.withOpacity(0.9),
                          secondaryColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.account_circle,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            occupiedSlotUserInfo!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          onPressed: () {
                            setState(() {
                              occupiedSlotUserInfo = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer.cancel();
    super.dispose();
  }
}