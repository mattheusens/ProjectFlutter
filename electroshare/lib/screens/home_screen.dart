import 'package:flutter/material.dart';
import 'package:electroshare/screens/navigation_side_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> devicesList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDevices();
  }

  Future<void> fetchDevices() async {
    setState(() {
      isLoading = true;
    });

    try {
      CollectionReference devices = FirebaseFirestore.instance.collection(
        'devices',
      );
      QuerySnapshot snapshot = await devices.get();

      List<Map<String, dynamic>> loadedDevices = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        loadedDevices.add({
          'id': doc.id,
          'title': data['title'] ?? 'No Title',
          'description': data['description'] ?? 'No Description',
          'price': data['price'] ?? 0.0,
          'imageBase64': data['image'] ?? '',
        });
      }

      setState(() {
        devicesList = loadedDevices;
        isLoading = false;
      });
    } catch (error) {
      print("Failed to fetch devices: $error");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devices'), centerTitle: true),
      drawer: const NavigationSideBar(),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: fetchDevices,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DeviceGrid(devices: devicesList),
                ),
              ),
    );
  }
}

class DeviceGrid extends StatelessWidget {
  final List<Map<String, dynamic>> devices;

  const DeviceGrid({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    return devices.isEmpty
        ? Center(child: Text('No devices found'))
        : LayoutBuilder(
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
                return DeviceCard(device: devices[index]);
              },
            );
          },
        );
  }
}

class DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;

  const DeviceCard({super.key, required this.device});

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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    device['title'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

            const SizedBox(height: 8),

            Text(
              device['description'],
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 323,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: imageWidget,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
