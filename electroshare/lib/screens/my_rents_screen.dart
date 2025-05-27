import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:electroshare/screens/navigation_side_bar.dart';

class MyRentsScreen extends StatefulWidget {
  const MyRentsScreen({super.key});

  @override
  State<MyRentsScreen> createState() => _MyRentalsScreenState();
}

class _MyRentalsScreenState extends State<MyRentsScreen> {
  bool _isLoading = true;
  List<RentalItem> _rentals = [];

  @override
  void initState() {
    super.initState();
    _fetchMyRentals();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _fetchMyRentals() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final devicesQuery =
          await FirebaseFirestore.instance.collection('devices').get();

      List<RentalItem> userRentals = [];

      for (var deviceDoc in devicesQuery.docs) {
        final deviceData = deviceDoc.data();
        final rentedData = deviceData['rented'] ?? [];

        if (rentedData is List) {
          for (var rental in rentedData) {
            String userId = '';
            DateTime rentalDate = DateTime.now();

            if (rental is Map<String, dynamic>) {
              userId = rental['userId'] ?? '';
              if (rental['date'] is Timestamp) {
                rentalDate = rental['date'].toDate();
              }
            } else if (rental is Timestamp) {
              continue;
            }

            if (userId == currentUser.uid &&
                (rentalDate.isAfter(DateTime.now()) ||
                    _isSameDate(rentalDate, DateTime.now()))) {
              userRentals.add(
                RentalItem(
                  deviceId: deviceDoc.id,
                  deviceTitle: deviceData['title'] ?? 'Unknown Device',
                  deviceDescription: deviceData['description'] ?? '',
                  devicePrice: deviceData['price']?.toDouble() ?? 0.0,
                  rentalDate: rentalDate,
                  rentedAt:
                      rental['rentedAt'] is Timestamp
                          ? rental['rentedAt'].toDate()
                          : null,
                ),
              );
            }
          }
        }
      }

      userRentals.sort((a, b) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final aDate = DateTime(
          a.rentalDate.year,
          a.rentalDate.month,
          a.rentalDate.day,
        );
        final bDate = DateTime(
          b.rentalDate.year,
          b.rentalDate.month,
          b.rentalDate.day,
        );

        final aIsUpcoming =
            aDate.isAfter(today) || aDate.isAtSameMomentAs(today);
        final bIsUpcoming =
            bDate.isAfter(today) || bDate.isAtSameMomentAs(today);

        if (aIsUpcoming && bIsUpcoming) {
          return a.rentalDate.compareTo(b.rentalDate);
        } else if (!aIsUpcoming && !bIsUpcoming) {
          return b.rentalDate.compareTo(a.rentalDate);
        } else {
          return aIsUpcoming ? -1 : 1;
        }
      });

      setState(() {
        _rentals = userRentals;
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading rentals: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rentals'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMyRentals,
          ),
        ],
      ),
      drawer: const NavigationSideBar(),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _rentals.isEmpty
              ? _buildEmptyState()
              : _buildRentalsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No rentals found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your rented devices will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalsList() {
    return RefreshIndicator(
      onRefresh: _fetchMyRentals,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 1;
            double cardWidth = constraints.maxWidth;

            if (constraints.maxWidth > 600) {
              crossAxisCount = 2;
              cardWidth = (constraints.maxWidth - 32) / 2;
            }

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: crossAxisCount == 2 ? 5 : 4,
              ),
              itemCount: _rentals.length,
              itemBuilder: (context, index) {
                return SizedBox(
                  height: 200,
                  child: _buildRentalCard(_rentals[index], cardWidth),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildRentalCard(RentalItem rental, double cardWidth) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    rental.deviceTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '€${rental.devicePrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Colors.blue.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd/MM/yyyy').format(rental.rentalDate),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (rental.rentedAt != null)
                  Text(
                    'Rented: ${DateFormat('dd/MM').format(rental.rentedAt!)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  )
                else
                  const SizedBox(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RentalItem {
  final String deviceId;
  final String deviceTitle;
  final String deviceDescription;
  final double devicePrice;
  final DateTime rentalDate;
  final DateTime? rentedAt;

  RentalItem({
    required this.deviceId,
    required this.deviceTitle,
    required this.deviceDescription,
    required this.devicePrice,
    required this.rentalDate,
    this.rentedAt,
  });
}
