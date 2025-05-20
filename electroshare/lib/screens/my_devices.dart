import 'package:flutter/material.dart';
import 'package:electroshare/screens/navigation_side_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';

class MyDevicesScreen extends StatefulWidget {
  const MyDevicesScreen({super.key});

  @override
  State<MyDevicesScreen> createState() => _MyDevicesScreenState();
}

class _MyDevicesScreenState extends State<MyDevicesScreen> {
  List<Map<String, dynamic>> devicesList = [];
  List<Map<String, dynamic>> filteredDevicesList = [];
  bool isLoading = true;
  String? selectedCategory;
  List<String> availableCategories = [];

  @override
  void initState() {
    super.initState();
    fetchMyDevices();
  }

  Future<void> fetchMyDevices() async {
    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("User not logged in");
      }

      final devices = FirebaseFirestore.instance.collection('devices');
      final snapshot =
          await devices.where('userId', isEqualTo: currentUser.uid).get();

      List<Map<String, dynamic>> loadedDevices = [];
      Set<String> categories = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] ?? 'Uncategorized';

        categories.add(category);

        loadedDevices.add({
          'id': doc.id,
          'title': data['title'] ?? 'No Title',
          'description': data['description'] ?? 'No Description',
          'price': data['price'] ?? 0.0,
          'imageBase64': data['image'] ?? '',
          'category': category,
          'createdAt': data['createdAt'] ?? Timestamp.now(),
        });
      }

      loadedDevices.sort((a, b) {
        Timestamp timestampA = a['createdAt'] as Timestamp;
        Timestamp timestampB = b['createdAt'] as Timestamp;
        return timestampB.compareTo(timestampA);
      });

      setState(() {
        devicesList = loadedDevices;
        filteredDevicesList = loadedDevices;
        availableCategories = categories.toList()..sort();
        isLoading = false;
      });
    } catch (error) {
      print("Failed to fetch devices: $error");
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading your devices: $error"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void applyFilters() {
    if (selectedCategory == null) {
      setState(() {
        filteredDevicesList = List.from(devicesList);
      });
    } else {
      setState(() {
        filteredDevicesList =
            devicesList
                .where((device) => device['category'] == selectedCategory)
                .toList();
      });
    }
  }

  void clearFilters() {
    setState(() {
      selectedCategory = null;
      filteredDevicesList = List.from(devicesList);
    });
  }

  void showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter by Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioListTile<String?>(
                  title: const Text('All Categories'),
                  value: null,
                  groupValue: selectedCategory,
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value;
                    });
                    Navigator.pop(context);
                    applyFilters();
                  },
                ),
                ...availableCategories.map((category) {
                  return RadioListTile<String>(
                    title: Text(category),
                    value: category,
                    groupValue: selectedCategory,
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                      });
                      Navigator.pop(context);
                      applyFilters();
                    },
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                clearFilters();
              },
              child: const Text('Clear Filter'),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteDevice(String deviceId) async {
    try {
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Device deleted successfully"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );

      fetchMyDevices();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting device: $error"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void editDevice(String deviceId) {
    Navigator.pushNamed(context, '/edit-device', arguments: deviceId).then((_) {
      fetchMyDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: availableCategories.isEmpty ? null : showFilterDialog,
            tooltip: 'Filter by Category',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchMyDevices,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const NavigationSideBar(),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: fetchMyDevices,
                child: Column(
                  children: [
                    if (selectedCategory != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Chip(
                              label: Text('Category: $selectedCategory'),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                clearFilters();
                              },
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child:
                          devicesList.isEmpty
                              ? _buildEmptyState(context)
                              : filteredDevicesList.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 60,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "No devices in category '$selectedCategory'",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: clearFilters,
                                      icon: const Icon(Icons.filter_list_off),
                                      label: const Text("Clear Filter"),
                                    ),
                                  ],
                                ),
                              )
                              : Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: MyDevicesGrid(
                                  devices: filteredDevicesList,
                                  onDelete: deleteDevice,
                                  onEdit: editDevice,
                                ),
                              ),
                    ),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add').then((_) {
            fetchMyDevices();
          });
        },
        child: const Icon(Icons.add),
        tooltip: 'Add New Device',
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "You haven't added any devices yet",
            style: TextStyle(
              fontSize: 18,
              color: const Color.fromARGB(255, 84, 84, 84),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap the + button to add a new device",
            style: TextStyle(
              fontSize: 16,
              color: const Color.fromARGB(255, 117, 117, 117),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/add');
            },
            icon: const Icon(Icons.add),
            label: const Text("Add New Device"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class MyDevicesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> devices;
  final Function(String) onDelete;
  final Function(String) onEdit;

  const MyDevicesGrid({
    super.key,
    required this.devices,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
            childAspectRatio: 1.2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: devices.length,
          itemBuilder: (context, index) {
            return MyDeviceCard(
              device: devices[index],
              onDelete: () => onDelete(devices[index]['id']),
              onEdit: () => onEdit(devices[index]['id']),
            );
          },
        );
      },
    );
  }
}

class MyDeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const MyDeviceCard({
    super.key,
    required this.device,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    String formattedPrice = '€${device['price']}';
    if (device['price'] is double) {
      formattedPrice = '€${device['price'].toStringAsFixed(2)}';
    }

    Widget imageWidget = const Center(
      child: Icon(Icons.device_unknown, size: 100, color: Colors.grey),
    );

    if (device['imageBase64'] != null &&
        device['imageBase64'].toString().isNotEmpty) {
      try {
        Uint8List bytes = base64Decode(device['imageBase64']);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.broken_image, size: 100, color: Colors.grey),
            );
          },
        );
      } catch (e) {
        print('Error decoding image: $e');
      }
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 12.0,
              right: 12.0,
              top: 12.0,
              bottom: 4.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        device['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (device['category'] != null &&
                          device['category'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            '• ${device['category']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  formattedPrice,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 4.0,
            ),
            child: Text(
              device['description'],
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: imageWidget,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Delete Device?'),
                            content: Text(
                              'Are you sure you want to delete "${device['title']}"? This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('CANCEL'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  onDelete();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('DELETE'),
                              ),
                            ],
                          ),
                    );
                  },
                  tooltip: 'Delete',
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
