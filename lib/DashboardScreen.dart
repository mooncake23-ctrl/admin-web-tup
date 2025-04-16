import 'package:flutter/material.dart';
import 'UsersScreen.dart';
import 'NotificationsScreen.dart';
import 'ParkingHistoryScreen.dart';
import 'ProfilesScreen.dart';
import 'StoresScreen.dart';
import 'ViolationsScreen.dart';
import 'CreateUserScreen.dart';
import 'ContactUsScreen.dart'; // Import the ContactUsScreen

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Widget _selectedScreen = UsersScreen(); // Default screen

  void _selectScreen(Widget screen) {
    setState(() {
      _selectedScreen = screen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation with matching Login Screen Colors
          Container(
            width: 250,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF71BFDC),
                  Color(0xFF9676D6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                SizedBox(height: 50),
                Text(
                  'Admin Panel',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                _buildSidebarButton('Screen Display', Icons.screen_lock_landscape, ProfilesScreen()),
                _buildSidebarButton('Users', Icons.people, UsersScreen()),
                _buildSidebarButton('Notifications', Icons.notifications, NotificationsScreen()),
                _buildSidebarButton('Parking History', Icons.history, ParkingHistoryScreen()),
                _buildSidebarButton('Stores', Icons.store, StoresScreen()),
                _buildSidebarButton('Violations', Icons.report, ViolationsScreen()),
                _buildSidebarButton('Create User', Icons.person_add, CreateUserScreen()),
                _buildSidebarButton('Contact Us', Icons.contact_mail, ContactUsScreen()), // Add Contact Us button
                Spacer(),
                Divider(color: Colors.white54),
                _buildSidebarButton('Logout', Icons.exit_to_app, null, isLogout: true),
              ],
            ),
          ),
          // Content Area with Matching Background
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFFFFF),
                    Color(0xFFF9F8FB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: EdgeInsets.all(20),
              child: _selectedScreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarButton(String title, IconData icon, Widget? screen, {bool isLogout = false}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: TextStyle(color: Colors.white)),
      onTap: () {
        if (isLogout) {
          _logout();
        } else {
          _selectScreen(screen!);
        }
      },
    );
  }

  void _logout() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
}
