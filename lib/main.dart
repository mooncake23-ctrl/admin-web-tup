import 'package:flutter/material.dart';
import 'dart:typed_data'; // For Uint8List
import 'LoginScreen.dart';
import 'DashboardScreen.dart';
import 'UsersScreen.dart';
import 'NotificationsScreen.dart';
import 'ParkingHistoryScreen.dart';
import 'ProfilesScreen.dart';
import 'StoresScreen.dart';
import 'ViolationsScreen.dart';
import 'CreateUserScreen.dart';
import 'SignUpScreen.dart';
import 'ContactUsScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AdminApp());
}

class AdminApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Panel',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blueAccent.withOpacity(0.8),
          elevation: 0,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: _routes,
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text("Page Not Found")),
          body: Center(
            child: Text(
              "404 - Page Not Found",
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }

  static final Map<String, WidgetBuilder> _routes = {
    '/login': (context) => LoginScreen(),
    '/dashboard': (context) => DashboardScreen(),
    '/users': (context) => UsersScreen(),
    '/notifications': (context) => NotificationsScreen(),
    '/parking_history': (context) => ParkingHistoryScreen(),
    '/profiles': (context) => ProfilesScreen(),
    '/stores': (context) => StoresScreen(),
    '/violations': (context) => ViolationsScreen(),
    '/create_user': (context) => CreateUserScreen(),
    '/signup': (context) => SignupScreen(),
    '/contact_us': (context) => ContactUsScreen(),
  };
}

