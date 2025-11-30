import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'balance_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const BalanceScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color.fromARGB(255, 251, 251, 251),
        indicatorColor: Colors.blue.shade50,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(color: Colors.grey);
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Colors.grey),
            selectedIcon: Icon(Icons.home, color: Colors.blue),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline, color: Colors.grey),
            selectedIcon: Icon(Icons.pie_chart, color: Colors.blue),
            label: 'Balance',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: Colors.grey),
            selectedIcon: Icon(Icons.person, color: Colors.blue),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
