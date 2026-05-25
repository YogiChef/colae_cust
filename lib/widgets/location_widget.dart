// ignore_for_file: avoid_print, deprecated_member_use
import 'package:colae_cut/services/sevice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:colae_cut/providers/app_info.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:colae_cut/models/directions.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Position? _currentPosition;
  String _currentAddress = 'กำลังโหลด...';
  String? _selectedMarkerId;

  @override
  void initState() {
    super.initState();
    _loadInitialLocation();
  }

  Future<void> _loadInitialLocation() async {
    final appInfo = Provider.of<AppInfo>(context, listen: false);

    if (appInfo.userLocation != null) {
      final savedDirections = appInfo.userLocation;

      print('Available fields: ${savedDirections.runtimeType}');

      try {
        setState(() {
          _currentPosition = Position(
            latitude: savedDirections!.locationLat!,
            longitude: savedDirections.locationLng!,
            timestamp: DateTime.now(),
            accuracy: 10.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            floor: null,
            isMocked: true,
          );
          _currentAddress = savedDirections.locationName ?? 'ไม่ทราบที่อยู่';
        });

        _addMarker(
          'saved_location',
          LatLng(savedDirections!.locationLat!, savedDirections.locationLng!),
          savedDirections.locationName ?? 'Saved Location',
          isDraggable: false,
        );

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(
                  savedDirections.locationLat!,
                  savedDirections.locationLng!,
                ),
                zoom: 15,
              ),
            ),
          );
        }

        print(
          'Loaded saved location: lat=${savedDirections.locationLat}, lng=${savedDirections.locationLng}, name=${savedDirections.locationName}',
        );
      } catch (e) {
        print(
          'Error accessing saved Directions fields: $e - Falling back to GPS',
        );
        await _getCurrentLocation();
        return;
      }
    } else {
      await _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationError('กรุณาเปิด Location Services');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationError('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationError('Location permissions are permanently denied');
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = position;
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    }

    _addMarker(
      'current_location',
      LatLng(position.latitude, position.longitude),
      'ที่อยู่ปัจจุบันของคุณ',
      isDraggable: false,
    );

    _currentAddress = await _getAddressFromPosition(position);
    setState(() {});
  }

  void _addMarker(
    String markerId,
    LatLng latLng,
    String title, {
    bool isDraggable = false,
  }) {
    setState(() {
      if (_selectedMarkerId != null &&
          _selectedMarkerId != 'current_location' &&
          _selectedMarkerId != 'saved_location') {
        _markers.removeWhere((m) => m.markerId.value == _selectedMarkerId);
      }

      final newMarker = Marker(
        markerId: MarkerId(markerId),
        position: latLng,
        infoWindow: InfoWindow(title: title),
        draggable: isDraggable,
        onDragEnd: isDraggable
            ? (newPosition) {
                _updateLocation(newPosition);
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: newPosition, zoom: 15),
                  ),
                );
              }
            : null,
        icon: isDraggable
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
      _markers.add(newMarker);

      if (isDraggable) {
        _selectedMarkerId = markerId;
      }
    });
  }

  Future<void> _saveLocation() async {
    if (_currentPosition == null) {
      _showLocationError('ไม่มี location ที่จะบันทึก');
      return;
    }

    final appInfo = Provider.of<AppInfo>(context, listen: false);

    final String addressToSave = _currentAddress.isEmpty
        ? 'ไม่ทราบที่อยู่'
        : _currentAddress;
    final Directions newDirections = Directions(
      locationName: addressToSave,
      locationLat: _currentPosition!.latitude,
      locationLng: _currentPosition!.longitude,
    );

    appInfo.updateLocationAddress(newDirections);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกที่อยู่เรียบร้อยแล้ว!')),
    );

    Navigator.pop(context);
  }

  Future<void> _updateLocation(LatLng newLatLng) async {
    _currentPosition = Position(
      latitude: newLatLng.latitude,
      longitude: newLatLng.longitude,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      floor: null,
      isMocked: true,
    );

    _currentAddress = await _getAddressFromPosition(_currentPosition!);
    setState(() {});
  }

  Future<String> _getAddressFromPosition(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        return 'ไม่ทราบที่อยู่';
      }
      Placemark place = placemarks[0];
      String street = place.street ?? place.name ?? '';
      String subLocality = place.subLocality ?? '';
      String locality = place.locality ?? '';
      String postalCode = place.postalCode ?? '';
      String adminArea = place.administrativeArea ?? '';
      String country = place.country ?? '';

      List<String> parts = [
        street,
        subLocality,
        locality,
        postalCode,
        adminArea,
        country,
      ].where((part) => part.isNotEmpty).toList();

      return parts.isEmpty ? 'ไม่ทราบที่อยู่' : parts.join(', ');
    } catch (e) {
      print('Error getting address: $e');
      return 'ไม่ทราบที่อยู่';
    }
  }

  void _showLocationError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ข้อผิดพลาด'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกที่อยู่'),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            ExpansionTile(
              initiallyExpanded: false,
              leading: const Icon(Icons.location_on, color: Colors.green),
              title: const Text(
                'ที่อยู่ปัจจุบัน',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentAddress,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13.sp,
                        ),
                        textAlign: TextAlign.left, //
                      ),
                      if (_currentPosition != null)
                        Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: Text(
                            'ความแม่นยำ: ${_currentPosition!.accuracy.toStringAsFixed(0)} เมตร',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11.sp,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: _currentPosition == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          Text('กำลังโหลด GPS...'),
                        ],
                      ),
                    )
                  : GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        if (_currentPosition != null) {
                          _mapController!.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: LatLng(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                ),
                                zoom: 15,
                              ),
                            ),
                          );
                        }
                      },
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15,
                      ),
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      tiltGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      compassEnabled: true,
                      mapType: MapType.normal,
                      onTap: (latLng) {
                        if (_selectedMarkerId != null &&
                            _selectedMarkerId != 'current_location' &&
                            _selectedMarkerId != 'saved_location') {
                          _markers.removeWhere(
                            (m) => m.markerId.value == _selectedMarkerId,
                          );
                        }
                        final newId =
                            'selected_${DateTime.now().millisecondsSinceEpoch}';
                        _addMarker(
                          newId,
                          latLng,
                          'ที่อยู่ที่เลือก',
                          isDraggable: true,
                        );
                        _updateLocation(latLng);
                        _mapController?.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(target: latLng, zoom: 15),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom + 12.h,
            left: 20.w,
            right: 20.w,
          ),
          child: ElevatedButton.icon(
            onPressed: _saveLocation,
            icon: const Icon(Icons.save, color: Colors.white),
            label: Text(
              'บันทึกที่อยู่',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: mainColor,
              minimumSize: Size(double.infinity, 50.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7.r),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
