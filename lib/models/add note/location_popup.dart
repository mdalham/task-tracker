import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../widget/custom_container.dart';

class LocationPopup extends StatefulWidget {
  final String? initialAddress;

  const LocationPopup({super.key, this.initialAddress});

  static Future<String?> show(BuildContext context, {String? initialAddress}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LocationPopup(initialAddress: initialAddress),
    );
  }

  @override
  State<LocationPopup> createState() => _LocationPopupState();
}

class _LocationPopupState extends State<LocationPopup> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAddress ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() {
      _errorMessage = msg;
      _isLoading = false;
    });
    print('Location error: $msg');
  }

  void _saveLocation() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomContainer(
          circularRadius: 20,
          color: cs.surface,
          outlineColor: cs.outline.withOpacity(0.5),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'Set Location',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Address field
                    CustomContainer(
                      color: cs.primaryContainer,
                      outlineColor: cs.outline,
                      circularRadius: 10,
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: TextField(
                        controller: _controller,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Enter your address',
                          border: InputBorder.none,
                          suffixIcon: _isLoading
                              ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                              : IconButton(
                            icon: const Icon(Icons.my_location),
                            onPressed: _detectLocation,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),

                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: tt.bodyMedium?.copyWith(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: tt.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _controller.text.trim().isEmpty
                              ? null
                              : _saveLocation,
                          label: Text('Save',style: tt.titleSmall!.copyWith(
                            color: Colors.white,
                            fontSize: 16
                          ),),
                          style: ElevatedButton.styleFrom(
                            disabledBackgroundColor: cs.primary.withOpacity(0.05),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _detectLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Check if location service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Please turn on Location in your phone settings.');
        return;
      }

      // 2. Check permission
      var permission = await Geolocator.checkPermission();

      // If denied → request (this shows the system dialog)
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        // User tapped "Deny" in dialog
        if (permission == LocationPermission.denied) {
          _showError(
            'Location permission denied. You can type address manually.',
          );
          return;
        }
      }

      // User tapped "Don't allow" → permanently denied
      if (permission == LocationPermission.deniedForever) {
        _showError(
          'Location access denied forever.\nGo to Settings → Apps → Task Tracker → Permissions → Allow Location',
        );
        return;
      }

      // 3. All good — get location with better settings
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 30),
        ),
      );

      print('Location found: ${position.latitude}, ${position.longitude}');

      if (!mounted) return;

      // 4. Convert to address (human-readable format only)
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (placemarks.isEmpty) {
          _showError('Could not find address for this location.');
          return;
        }

        final place = placemarks.first;

        // Build human-readable address (NO coordinates)
        final address = _buildHumanReadableAddress(place);

        if (address.isEmpty) {
          _showError('Could not get a proper address. Please type manually.');
          return;
        }

        _controller.text = address;

        if (mounted) {
          setState(() => _isLoading = false);
        }
      } catch (geocodingError) {
        print('Geocoding error: $geocodingError');
        _showError('Could not get address. Please type manually.');
      }
    } on TimeoutException catch (e) {
      print('Timeout: $e');
      _showError('Location timeout – try again or type manually');
    } on LocationServiceDisabledException catch (e) {
      print('Service disabled: $e');
      _showError('Location service is disabled. Please enable it in settings.');
    } on PermissionDeniedException catch (e) {
      print('Permission denied: $e');
      _showError('Location permission denied.');
    } catch (e) {
      print('Location error: $e');
      String msg = 'Could not detect location';
      if (e.toString().contains('TIMEOUT')) {
        msg = 'GPS timeout – try again or type manually';
      } else if (e.toString().contains('accuracy')) {
        msg = 'Poor GPS signal. Try again in a few seconds.';
      }
      _showError(msg);
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Build a human-readable address from placemark
  /// Format: Street, Area, City, State, Country
  /// NO coordinates or postal codes
  String _buildHumanReadableAddress(Placemark place) {
    final parts = <String>[];

    // Add street/thoroughfare (e.g., "123 Main Street")
    if (place.street?.isNotEmpty ?? false) {
      parts.add(place.street!);
    } else if (place.thoroughfare?.isNotEmpty ?? false) {
      parts.add(place.thoroughfare!);
    } else if (place.name?.isNotEmpty ?? false) {
      // Only use name if no street available
      parts.add(place.name!);
    }

    // Add area/neighborhood
    if (place.subLocality?.isNotEmpty ?? false) {
      parts.add(place.subLocality!);
    }

    // Add city/locality
    if (place.locality?.isNotEmpty ?? false) {
      parts.add(place.locality!);
    } else if (place.subAdministrativeArea?.isNotEmpty ?? false) {
      parts.add(place.subAdministrativeArea!);
    }

    // Add state/administrative area
    if (place.administrativeArea?.isNotEmpty ?? false) {
      parts.add(place.administrativeArea!);
    }

    // Add country
    if (place.country?.isNotEmpty ?? false) {
      parts.add(place.country!);
    }

    return parts.join(', ');
  }
}