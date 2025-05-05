import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_frame/flutter_web_frame.dart';
import 'dart:typed_data';
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

// Global navigator key for web navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize web-specific settings if running on web
  if (kIsWeb) {
    // You can add web-specific initializations here
  }

  runApp(AdminApp());
}

class AdminApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Panel',
      debugShowCheckedModeBanner: false,
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

      // Web-specific configurations
      useInheritedMediaQuery: true,
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return kIsWeb
            ? FlutterWebFrame(
          maximumSize: Size(1920, 1080),
          enabled: true,
          builder: (context) => child!,
        )
            : child!;
      },

      // Routing configuration
      initialRoute: '/login',
      routes: _routes,

      // Handle unknown routes (404)
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

      // Handle web URL navigation
      onGenerateRoute: (settings) {
        if (kIsWeb) {
          final routeBuilder = _routes[settings.name];
          if (routeBuilder != null) {
            return MaterialPageRoute(
              builder: routeBuilder,
              settings: settings,
            );
          }
        }
        return null;
      },
    );
  }

  // App routes
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