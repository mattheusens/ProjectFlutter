import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;

class NavigationSideBar extends StatelessWidget {
  const NavigationSideBar({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String email = user?.email ?? 'Guest User';
    final String initials =
        email.isNotEmpty
            ? email
                .split('@')[0]
                .substring(0, min(2, email.split('@')[0].length))
                .toUpperCase()
            : 'GU';

    return Drawer(
      elevation: 16.0,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              email.split('@')[0],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              image: const DecorationImage(
                image: AssetImage('assets/images/drawer_header_bg.jpg'),
                fit: BoxFit.cover,
                opacity: 0.4,
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
                  child: Text(
                    'BROWSE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                NavItem(
                  icon: Icons.devices,
                  title: 'All Devices',
                  route: '/home',
                  selected: ModalRoute.of(context)?.settings.name == '/home',
                ),
                NavItem(
                  icon: Icons.category,
                  title: 'Categories',
                  route: '/categories',
                  selected:
                      ModalRoute.of(context)?.settings.name == '/categories',
                ),
                NavItem(
                  icon: Icons.schedule,
                  title: 'My Rents',
                  route: '/my-rents',
                  selected:
                      ModalRoute.of(context)?.settings.name == '/my-rents',
                ),

                const Padding(
                  padding: EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
                  child: Text(
                    'MY DEVICES',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                NavItem(
                  icon: Icons.inventory,
                  title: 'My Devices',
                  route: '/my-devices',
                  selected:
                      ModalRoute.of(context)?.settings.name == '/my-devices',
                  showBadge: true,
                ),
                NavItem(
                  icon: Icons.add_circle_outline,
                  title: 'Add Device',
                  route: '/add',
                  selected: ModalRoute.of(context)?.settings.name == '/add',
                ),
                NavItem(
                  icon: Icons.schedule,
                  title: 'Rental',
                  route: '/rental',
                  selected: ModalRoute.of(context)?.settings.name == '/rental',
                ),

                const Divider(),

                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () async {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text(
                              'Are you sure you want to logout?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('CANCEL'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('LOGOUT'),
                              ),
                            ],
                          ),
                    );

                    if (shouldLogout == true) {
                      Navigator.pop(context);
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ElectroShare v1.0.0',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int min(int a, int b) {
    return a < b ? a : b;
  }
}

class NavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;
  final bool selected;
  final bool showBadge;

  const NavItem({
    super.key,
    required this.icon,
    required this.title,
    required this.route,
    this.selected = false,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            selected
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : Colors.transparent,
        border:
            selected
                ? Border(
                  left: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 4,
                  ),
                )
                : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: selected ? Theme.of(context).primaryColor : null,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Theme.of(context).primaryColor : null,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          if (route != ModalRoute.of(context)?.settings.name) {
            Navigator.pushReplacementNamed(context, route);
          }
        },
      ),
    );
  }
}
