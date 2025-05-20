import 'package:flutter/material.dart';
import 'package:electroshare/screens/navigation_side_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class RentalScreen extends StatefulWidget {
  const RentalScreen({super.key});

  @override
  State<RentalScreen> createState() => _RentalScreenState();
}

class _RentalScreenState extends State<RentalScreen> {
  String? _selectedOption;
  List<Map<String, dynamic>> _devicesList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyDevices();
  }

  List<DateTime> parseTimestamps(dynamic list) {
    if (list is List) {
      return list.map<DateTime>((entry) {
        return (entry as Timestamp).toDate();
      }).toList();
    }
    return [];
  }

  Future<void> _fetchMyDevices() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final snapshot =
          await FirebaseFirestore.instance
              .collection('devices')
              .where('userId', isEqualTo: currentUser.uid)
              .get();

      final loadedDevices =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['title'] ?? 'No Title',
              'availability': parseTimestamps(data['availability']),
              'rented': parseTimestamps(data['rented']),
            };
          }).toList();

      setState(() {
        _devicesList = loadedDevices;
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading devices: $error"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dropdownItems =
        _devicesList.map((device) {
          final title = device['title'] ?? 'Unnamed Device';
          return DropdownMenuItem<String>(
            value: title,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(title, style: const TextStyle(color: Colors.black)),
            ),
          );
        }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rentals'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 160,
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Select Device',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                dropdownColor: Colors.white,
                value: _selectedOption,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                style: const TextStyle(color: Colors.black),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedOption = newValue;
                  });
                },
                items: dropdownItems,
              ),
            ),
          ),
        ],
      ),
      drawer: const NavigationSideBar(),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : CalenderScreen(
                devicesList: _devicesList,
                selectedDeviceTitle: _selectedOption,
                onAvailabilityUpdated: _fetchMyDevices,
              ),
    );
  }
}

class CalenderScreen extends StatefulWidget {
  final List<Map<String, dynamic>> devicesList;
  final String? selectedDeviceTitle;
  final Function() onAvailabilityUpdated;

  const CalenderScreen({
    super.key,
    required this.devicesList,
    required this.selectedDeviceTitle,
    required this.onAvailabilityUpdated,
  });

  @override
  State<CalenderScreen> createState() => _CalenderScreen();
}

class _CalenderScreen extends State<CalenderScreen> {
  late DateTime _focusedDay;
  late DateTime _firstDay;
  late DateTime _lastDay;
  late Set<DateTime> _customSelectedDays;
  late Set<DateTime> _daysToDelete;
  bool _isSaving = false;
  bool _isDeleteMode = false;

  Map<String, dynamic>? get selectedDevice {
    if (widget.selectedDeviceTitle == null) return null;

    return widget.devicesList.firstWhere(
      (d) => d['title'] == widget.selectedDeviceTitle,
      orElse: () => {},
    );
  }

  List<DateTime> getMarkedDates() {
    final device = selectedDevice;
    if (device == null) return [];

    final availability = device['availability'] as List<DateTime>?;
    return availability ?? [];
  }

  List<DateTime> getRentedDates() {
    final device = selectedDevice;
    if (device == null) return [];

    final rented = device['rented'] as List<DateTime>?;
    return rented ?? [];
  }

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _firstDay = DateTime.now().subtract(const Duration(days: 1000));
    _lastDay = DateTime.now().add(const Duration(days: 1000));
    _customSelectedDays = {};
    _daysToDelete = {};
  }

  Future<void> _saveAvailabilities() async {
    if (selectedDevice == null ||
        (_customSelectedDays.isEmpty && _daysToDelete.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a device and at least one date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final deviceId = selectedDevice!['id'];

      final currentAvailability = await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .get()
          .then((doc) => doc.data()?['availability'] ?? []);

      final List<DateTime> existingDates = parseTimestamps(currentAvailability);

      if (_isDeleteMode) {
        final remainingDates =
            existingDates
                .where((date) => !_daysToDelete.any((d) => isSameDay(d, date)))
                .toList();

        final timestamps =
            remainingDates.map((date) => Timestamp.fromDate(date)).toList();

        await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .update({'availability': timestamps});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_daysToDelete.length} availabilities removed successfully',
              ),
            ),
          );
          setState(() {
            _daysToDelete = {};
          });
        }
      } else {
        final allDates = {...existingDates, ..._customSelectedDays}.toList();

        final timestamps =
            allDates.map((date) => Timestamp.fromDate(date)).toList();

        await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .update({'availability': timestamps});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Availabilities updated successfully'),
            ),
          );
          setState(() {
            _customSelectedDays = {};
          });
        }
      }

      widget.onAvailabilityUpdated();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update availabilities: $error'),
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

  @override
  Widget build(BuildContext context) {
    final availabilityDates = getMarkedDates();
    final rentedDates = getRentedDates();
    final bool canUpdate = widget.selectedDeviceTitle != null;

    return Column(
      children: [
        if (!canUpdate)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Please select a device to manage availability',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
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
            onDaySelected: (selectedDay, focusedDay) {
              if (!canUpdate) return;

              setState(() {
                _focusedDay = focusedDay;
                final normalizedDay = DateTime(
                  selectedDay.year,
                  selectedDay.month,
                  selectedDay.day,
                  12,
                );

                // Check if the day is already rented
                final isRented = rentedDates.any(
                  (d) => isSameDay(d, normalizedDay),
                );

                if (_isDeleteMode) {
                  final isAvailable = availabilityDates.any(
                    (d) => isSameDay(d, normalizedDay),
                  );
                  if (isAvailable) {
                    if (_daysToDelete.any((d) => isSameDay(d, normalizedDay))) {
                      _daysToDelete.removeWhere(
                        (d) => isSameDay(d, normalizedDay),
                      );
                    } else {
                      _daysToDelete.add(normalizedDay);
                    }
                  }
                } else {
                  // In Add mode, only allow selection if the day is not rented
                  if (!isRented) {
                    if (_customSelectedDays.any(
                      (d) => isSameDay(d, normalizedDay),
                    )) {
                      _customSelectedDays.removeWhere(
                        (d) => isSameDay(d, normalizedDay),
                      );
                    } else {
                      _customSelectedDays.add(normalizedDay);
                    }
                  }
                }
              });
            },
            selectedDayPredicate: (day) => false,
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final isSelected =
                    _isDeleteMode
                        ? _daysToDelete.any((d) => isSameDay(d, day))
                        : _customSelectedDays.any((d) => isSameDay(d, day));

                final isAvailable = availabilityDates.any(
                  (d) => isSameDay(d, day),
                );

                final isRented = rentedDates.any((d) => isSameDay(d, day));

                if (isSelected) {
                  return _buildCell(
                    day,
                    _isDeleteMode ? Colors.red : Colors.green,
                  );
                } else if (isRented) {
                  return _buildCell(day, Colors.orange);
                } else if (isAvailable) {
                  return _buildCell(day, Colors.grey);
                }
                return null;
              },
              todayBuilder: (context, day, focusedDay) {
                final isSelected =
                    _isDeleteMode
                        ? _daysToDelete.any((d) => isSameDay(d, day))
                        : _customSelectedDays.any((d) => isSameDay(d, day));

                final isAvailable = availabilityDates.any(
                  (d) => isSameDay(d, day),
                );

                final isRented = rentedDates.any((d) => isSameDay(d, day));

                if (isSelected) {
                  return _buildCell(
                    day,
                    _isDeleteMode ? Colors.red : Colors.green,
                  );
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
            ),
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(color: Colors.red),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextFormatter:
                  (date, locale) => DateFormat.yMMMM(locale).format(date),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isDeleteMode
                        ? 'Delete mode - Selected: ${_daysToDelete.length}'
                        : 'Add mode - Selected: ${_customSelectedDays.length}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isDeleteMode ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed:
                        canUpdate && !_isSaving
                            ? () {
                              setState(() {
                                _isDeleteMode = !_isDeleteMode;
                                _customSelectedDays = {};
                                _daysToDelete = {};
                              });
                            }
                            : null,
                    icon: Icon(
                      _isDeleteMode ? Icons.add_circle : Icons.delete,
                      color: _isDeleteMode ? Colors.green : Colors.red,
                    ),
                    label: Text(
                      _isDeleteMode ? 'Switch to Add' : 'Switch to Delete',
                      style: TextStyle(
                        color: _isDeleteMode ? Colors.green : Colors.red,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _isDeleteMode ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // This appears to be a duplicate UI element - consider removing it
              Text(
                _isDeleteMode
                    ? 'Delete mode - Selected: ${_daysToDelete.length}'
                    : 'Add mode - Selected: ${_customSelectedDays.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isDeleteMode ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    canUpdate &&
                            !_isSaving &&
                            ((_isDeleteMode && _daysToDelete.isNotEmpty) ||
                                (!_isDeleteMode &&
                                    _customSelectedDays.isNotEmpty))
                        ? () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(
                                  _isDeleteMode
                                      ? 'Delete Availabilities?'
                                      : 'Add Availabilities?',
                                ),
                                content: Text(
                                  _isDeleteMode
                                      ? 'Remove ${_daysToDelete.length} dates from availability?'
                                      : 'Add ${_customSelectedDays.length} dates to availability?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _saveAvailabilities();
                                    },
                                    child: const Text('Confirm'),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDeleteMode ? Colors.red : Colors.green,
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
                        : Text(
                          _isDeleteMode
                              ? 'Delete Availabilities'
                              : 'Add Availabilities',
                        ),
              ),
            ],
          ),
        ),
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
