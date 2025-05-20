import 'package:flutter/material.dart';
import 'package:electroshare/screens/navigation_side_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class RentScreen extends StatefulWidget {
  final String deviceId;
  final String deviceTitle;

  const RentScreen({
    super.key,
    required this.deviceId,
    required this.deviceTitle,
  });

  @override
  State<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends State<RentScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _deviceData = {};
  Set<DateTime> _selectedRentalDates = {};
  bool _isSaving = false;

  late DateTime _focusedDay;
  late DateTime _firstDay;
  late DateTime _lastDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _firstDay = DateTime.now();
    _lastDay = DateTime.now().add(const Duration(days: 365));
    _fetchDeviceData();
  }

  List<DateTime> parseTimestamps(dynamic list) {
    if (list is List) {
      return list.map<DateTime>((entry) {
        if (entry is Timestamp) {
          return entry.toDate();
        }
        return DateTime.now();
      }).toList();
    }
    return [];
  }

  Future<void> _fetchDeviceData() async {
    setState(() => _isLoading = true);

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('devices')
              .doc(widget.deviceId)
              .get();

      if (!doc.exists) {
        throw Exception("Device not found");
      }

      final data = doc.data()!;

      setState(() {
        _deviceData = {
          'id': doc.id,
          'title': data['title'] ?? 'No Title',
          'description': data['description'] ?? 'No Description',
          'price': data['price'] ?? 0.0,
          'availability': parseTimestamps(data['availability'] ?? []),
          'rented': parseTimestamps(data['rented'] ?? []),
        };
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading device data: $error"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rentDevice() async {
    if (_selectedRentalDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one date to rent'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Get the current rented dates
      final currentRented = await FirebaseFirestore.instance
          .collection('devices')
          .doc(widget.deviceId)
          .get()
          .then((doc) => doc.data()?['rented'] ?? []);

      // Get current availability dates
      final currentAvailability = await FirebaseFirestore.instance
          .collection('devices')
          .doc(widget.deviceId)
          .get()
          .then((doc) => doc.data()?['availability'] ?? []);

      final List<DateTime> existingRentedDates = parseTimestamps(currentRented);
      final List<DateTime> existingAvailabilityDates = parseTimestamps(
        currentAvailability,
      );

      final allRentedDates =
          {...existingRentedDates, ..._selectedRentalDates}.toList();
      final rentedTimestamps =
          allRentedDates.map((date) => Timestamp.fromDate(date)).toList();

      final updatedAvailabilityDates =
          existingAvailabilityDates
              .where(
                (date) => !_selectedRentalDates.any((d) => isSameDay(d, date)),
              )
              .toList();

      final availabilityTimestamps =
          updatedAvailabilityDates
              .map((date) => Timestamp.fromDate(date))
              .toList();

      await FirebaseFirestore.instance
          .collection('devices')
          .doc(widget.deviceId)
          .update({
            'rented': rentedTimestamps,
            'availability': availabilityTimestamps,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device rented successfully'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _selectedRentalDates = {};
          _deviceData['rented'] = allRentedDates;
          _deviceData['availability'] = updatedAvailabilityDates;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to rent device: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<DateTime> availabilityDates = _deviceData['availability'] ?? [];
    final List<DateTime> rentedDates = _deviceData['rented'] ?? [];

    // Format price for display
    final String priceDisplay =
        _deviceData['price'] != null
            ? '€${(_deviceData['price'] is double) ? _deviceData['price'].toStringAsFixed(2) : _deviceData['price']}'
            : '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rent ${widget.deviceTitle} '),
            Text(
              priceDisplay,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      drawer: const NavigationSideBar(),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        _buildLegendItem('Available', Colors.grey),
                        const SizedBox(width: 16),
                        _buildLegendItem('Rented', Colors.orange),
                        const SizedBox(width: 16),
                        _buildLegendItem('Selected', Colors.green),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TableCalendar(
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      focusedDay: _focusedDay,
                      firstDay: _firstDay,
                      lastDay: _lastDay,
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                      selectedDayPredicate: (day) {
                        // This needs to return true for days that should be marked as selected
                        return _selectedRentalDates.any(
                          (d) => isSameDay(d, day),
                        );
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        final normalizedDay = DateTime(
                          selectedDay.year,
                          selectedDay.month,
                          selectedDay.day,
                          12,
                        );

                        // Check if day is available (not rented)
                        final isAvailable = availabilityDates.any(
                          (d) => isSameDay(d, normalizedDay),
                        );
                        final isRented = rentedDates.any(
                          (d) => isSameDay(d, normalizedDay),
                        );

                        setState(() {
                          _focusedDay = focusedDay;

                          // Only allow selection if the day is available and not rented
                          if (isAvailable && !isRented) {
                            if (_selectedRentalDates.any(
                              (d) => isSameDay(d, normalizedDay),
                            )) {
                              _selectedRentalDates.removeWhere(
                                (d) => isSameDay(d, normalizedDay),
                              );
                            } else {
                              _selectedRentalDates.add(normalizedDay);
                            }
                          }
                        });
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          final isSelected = _selectedRentalDates.any(
                            (d) => isSameDay(d, day),
                          );
                          final isAvailable = availabilityDates.any(
                            (d) => isSameDay(d, day),
                          );
                          final isRented = rentedDates.any(
                            (d) => isSameDay(d, day),
                          );

                          if (isSelected) {
                            return _buildCell(day, Colors.green);
                          } else if (isRented) {
                            return _buildCell(day, Colors.orange);
                          } else if (isAvailable) {
                            return _buildCell(day, Colors.grey);
                          }
                          return null;
                        },
                        todayBuilder: (context, day, focusedDay) {
                          final isSelected = _selectedRentalDates.any(
                            (d) => isSameDay(d, day),
                          );
                          final isAvailable = availabilityDates.any(
                            (d) => isSameDay(d, day),
                          );
                          final isRented = rentedDates.any(
                            (d) => isSameDay(d, day),
                          );

                          if (isSelected) {
                            return _buildCell(day, Colors.green);
                          } else if (isRented) {
                            return _buildCell(day, Colors.orange);
                          } else if (isAvailable) {
                            return _buildCell(day, Colors.grey);
                          }
                          return _buildCell(
                            day,
                            const Color.fromARGB(255, 106, 105, 105),
                          );
                        },
                        markerBuilder: (context, day, events) {
                          // You can add markers here if needed
                          return null;
                        },
                      ),
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false,
                        weekendTextStyle: TextStyle(color: Colors.red),
                        // Make sure selection decoration is visible
                        selectedDecoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextFormatter:
                            (date, locale) =>
                                DateFormat.yMMMM(locale).format(date),
                        titleTextStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        leftChevronIcon: const Icon(
                          Icons.chevron_left,
                          color: Colors.black,
                        ),
                        rightChevronIcon: const Icon(
                          Icons.chevron_right,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Selected dates: ${_selectedRentalDates.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed:
                              _selectedRentalDates.isNotEmpty && !_isSaving
                                  ? _rentDevice
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child:
                              _isSaving
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Rent Device'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  Widget _buildCell(DateTime day, Color color) {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text('${day.day}', style: const TextStyle(color: Colors.white)),
    );
  }
}
