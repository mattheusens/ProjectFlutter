import 'package:flutter/material.dart';
import 'package:electroshare/screens/navigation_side_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:electroshare/screens/rent_screen.dart';
import 'package:electroshare/screens/map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> devicesList = [];
  List<Map<String, dynamic>> filteredDevicesList = [];
  bool isLoading = true;
  bool _mounted = true;

  String? selectedCategory;
  double? selectedDistance;
  LatLng? userLocation;
  LatLng? userAddress;
  bool isLocationLoading = false;

  final List<double> distanceOptions = [1, 5, 10, 25, 50, 100];
  final List<String> categories = ['Kitchen', 'Garden'];

  @override
  void initState() {
    super.initState();
    fetchDevices();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> fetchDevices() async {
    if (_mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      CollectionReference devices = FirebaseFirestore.instance.collection(
        'devices',
      );
      QuerySnapshot snapshot = await devices.get();

      List<Map<String, dynamic>> loadedDevices = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        Map<String, dynamic>? locationData =
            data['location'] as Map<String, dynamic>?;
        LatLng? deviceLocation;
        String? address;

        if (locationData != null) {
          dynamic rawLat = locationData['latitude'];
          dynamic rawLon = locationData['longitude'];

          double? lat = (rawLat is num) ? rawLat.toDouble() : null;
          double? lon = (rawLon is num) ? rawLon.toDouble() : null;

          if (lat != null && lon != null) {
            deviceLocation = LatLng(lat, lon);
          }

          address = locationData['address'] as String?;
        }

        dynamic rawPrice = data['price'];
        double price = 0.0;
        if (rawPrice is num) {
          price = rawPrice.toDouble();
        } else if (rawPrice is String) {
          price = double.tryParse(rawPrice) ?? 0.0;
        }

        loadedDevices.add({
          'id': doc.id,
          'title': data['title'] ?? 'No Title',
          'description': data['description'] ?? 'No Description',
          'price': price,
          'imageBase64': data['image'] ?? '',
          'category': data['category'] ?? '',
          'location': deviceLocation,
          'address': address,
        });
      }

      if (_mounted) {
        setState(() {
          devicesList = loadedDevices;
          filteredDevicesList = List.from(loadedDevices);
          isLoading = false;
        });
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch devices: $error')),
      );
      if (_mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> getUserLocation() async {
    if (_mounted) {
      setState(() {
        isLocationLoading = true;
      });
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          if (_mounted) {
            setState(() {
              isLocationLoading = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied, please enable them in settings',
            ),
          ),
        );
        if (_mounted) {
          setState(() {
            isLocationLoading = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition();

      if (_mounted) {
        setState(() {
          userLocation = LatLng(position.latitude, position.longitude);
          isLocationLoading = false;
        });
      }
    } catch (e) {
      if (_mounted) {
        setState(() {
          isLocationLoading = false;
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    }
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    final double meters = distance.as(LengthUnit.Meter, point1, point2);
    return meters / 1000;
  }

  void applyFilters() {
    if (!_mounted) return;

    List<Map<String, dynamic>> filtered = List.from(devicesList);

    if (selectedCategory != null && selectedCategory!.isNotEmpty) {
      filtered =
          filtered
              .where((device) => device['category'] == selectedCategory)
              .toList();
    }

    if (selectedDistance != null &&
        (userAddress != null || userLocation != null)) {
      final referenceLocation = userAddress ?? userLocation!;

      filtered =
          filtered.where((device) {
            final deviceLocation = device['location'];
            if (deviceLocation == null || !(deviceLocation is LatLng)) {
              return false;
            }

            double distance = calculateDistance(
              referenceLocation,
              deviceLocation,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Device: ${device['title']}, Distance: $distance km',
                ),
              ),
            );
            return distance <= selectedDistance!;
          }).toList();
    }

    if (_mounted) {
      setState(() {
        filteredDevicesList = filtered;
      });
    }
  }

  void clearFilters() {
    if (_mounted) {
      setState(() {
        selectedCategory = null;
        selectedDistance = null;
        userAddress = null;
        filteredDevicesList = List.from(devicesList);
      });
    }
  }

  void showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Filter Devices'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Category:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: selectedCategory == null,
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() {
                                  selectedCategory = null;
                                });
                              }
                            },
                          ),
                          ...categories.map((category) {
                            return FilterChip(
                              label: Text(category),
                              selected: selectedCategory == category,
                              onSelected: (selected) {
                                setDialogState(() {
                                  selectedCategory = selected ? category : null;
                                });
                              },
                            );
                          }).toList(),
                        ],
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Distance:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await getUserLocation();
                                if (_mounted) {
                                  showFilterDialog();
                                }
                              },
                              icon:
                                  isLocationLoading
                                      ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(Icons.my_location),
                              label: const Text('Current'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    userLocation != null && userAddress == null
                                        ? Colors.blue
                                        : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.of(context).pop();

                                final result =
                                    await Navigator.push<Map<String, dynamic>>(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => MapScreen(
                                              initialLocation:
                                                  userAddress ?? userLocation,
                                              initialAddress:
                                                  userAddress != null
                                                      ? 'Selected from map'
                                                      : null,
                                            ),
                                      ),
                                    );

                                if (result != null && _mounted) {
                                  setState(() {
                                    userAddress = result['location'] as LatLng?;
                                  });
                                  if (_mounted) {
                                    showFilterDialog();
                                  }
                                } else if (_mounted) {
                                  showFilterDialog();
                                }
                              },
                              icon: const Icon(Icons.map),
                              label: const Text('Map'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    userAddress != null ? Colors.blue : null,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (userLocation != null || userAddress != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    userAddress != null
                                        ? Icons.map
                                        : Icons.my_location,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    userAddress != null
                                        ? 'Selected from map:'
                                        : 'Current location:',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userAddress != null
                                    ? '${userAddress!.latitude.toStringAsFixed(4)}, ${userAddress!.longitude.toStringAsFixed(4)}'
                                    : '${userLocation!.latitude.toStringAsFixed(4)}, ${userLocation!.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('Any distance'),
                              selected: selectedDistance == null,
                              onSelected: (selected) {
                                if (selected) {
                                  setDialogState(() {
                                    selectedDistance = null;
                                  });
                                }
                              },
                            ),
                            ...distanceOptions.map((distance) {
                              return FilterChip(
                                label: Text('$distance km'),
                                selected: selectedDistance == distance,
                                onSelected: (selected) {
                                  setDialogState(() {
                                    selectedDistance =
                                        selected ? distance : null;
                                  });
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ] else
                        const Text(
                          'Select a location to filter by distance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      clearFilters();
                    },
                    child: const Text('Clear All'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      applyFilters();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayDevices = filteredDevicesList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: showFilterDialog,
          ),
        ],
      ),
      drawer: const NavigationSideBar(),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: fetchDevices,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      if (selectedCategory != null || selectedDistance != null)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              if (selectedCategory != null)
                                Chip(
                                  label: Text('Category: $selectedCategory'),
                                  onDeleted: () {
                                    setState(() {
                                      selectedCategory = null;
                                      applyFilters();
                                    });
                                  },
                                ),
                              if (selectedDistance != null)
                                Chip(
                                  label: Text(
                                    'Distance: $selectedDistance km ${userAddress != null ? "(Map)" : "(Current)"}',
                                  ),
                                  onDeleted: () {
                                    setState(() {
                                      selectedDistance = null;
                                      userAddress = null;
                                      applyFilters();
                                    });
                                  },
                                ),
                              ActionChip(
                                label: const Text('Clear All'),
                                onPressed: () {
                                  clearFilters();
                                },
                              ),
                            ],
                          ),
                        ),
                      Expanded(child: DeviceGrid(devices: displayDevices)),
                    ],
                  ),
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
        ? const Center(child: Text('No devices found'))
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error decoding image: $e')));
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => RentScreen(
                  deviceId: device['id'],
                  deviceTitle: device['title'],
                ),
          ),
        );
      },
      child: Card(
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

            if (device['address'] != null &&
                device['address'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  left: 12.0,
                  right: 12.0,
                  bottom: 4.0,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        device['address'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
          ],
        ),
      ),
    );
  }
}
