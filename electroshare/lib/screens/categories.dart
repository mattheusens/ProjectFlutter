import 'package:flutter/material.dart';
import 'package:electroshare/screens/navigation_side_bar.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> categories = [
      {
        'name': 'Cleaning',
        'examples': [
          'Vacuum Cleaner',
          'Steam Cleaner',
          'Pressure Washer',
          'Carpet Cleaner',
          'Air Purifier',
          'Floor Polisher',
        ],
        'color': Colors.blue,
        'icon': Icons.cleaning_services,
      },
      {
        'name': 'Garden',
        'examples': [
          'Lawn Mower',
          'Hedge Trimmer',
          'Leaf Blower',
          'Garden Shredder',
          'Electric Chainsaw',
          'Tiller',
        ],
        'color': Colors.green,
        'icon': Icons.grass,
      },
      {
        'name': 'Kitchen',
        'examples': [
          'Stand Mixer',
          'Food Processor',
          'Blender',
          'Juicer',
          'Sous Vide',
          'Ice Cream Maker',
        ],
        'color': Colors.orange,
        'icon': Icons.kitchen,
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Categories'), centerTitle: true),
      drawer: const NavigationSideBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Find examples for electronics to rent organized by category',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount;
                  if (constraints.maxWidth > 900) {
                    crossAxisCount = 3;
                  } else if (constraints.maxWidth > 600) {
                    crossAxisCount = 2;
                  } else {
                    crossAxisCount = 1;
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      return CategoryCard(
                        category: categories[index],
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/',
                            arguments: {'category': categories[index]['name']},
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final Map<String, dynamic> category;
  final VoidCallback onTap;

  const CategoryCard({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: category['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category['icon'],
                  color: category['color'],
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                category['name'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              const Divider(),
              const SizedBox(height: 6),

              const Text(
                'Examples:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: category['examples'].length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.arrow_right,
                            size: 16,
                            color: category['color'],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              category['examples'][index],
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
