// ignore_for_file: use_build_context_synchronously, avoid_print, deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:colae_cut/assistants/assistant_methods.dart';
import 'package:colae_cut/assistants/geofire_assistant.dart';
import 'package:colae_cut/models/active_nearby_drers.dart';
import 'package:colae_cut/services/sevice.dart';
import 'dart:ui' as ui;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  String userName = 'Your Name';
  String userEmail = 'Your Email';
  bool activeNearbyDriverKeysLoaded = false;
  Set<Marker> markers = {};
  Set<Circle> circles = {};
  LocationPermission? _locationPermission;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(18.776399092977652, 100.77179618562121),
    zoom: 14.4746,
  );

  void blackThemeGoogleMap() {
    mapController!.setMapStyle('''
                    [
                      {
                        "elementType": "geometry",
                        "stylers": [
                          {
                            "color": "#242f3e"
                          }
                        ]
                      },
                      {
                        "elementType": "labels.text.fill",
                        "stylers": [
                          {
                            "color": "#746855"
                          }
                        ]
                      },
                      {
                        "elementType": "labels.text.stroke",
                        "stylers": [
                          {
                            "color": "#242f3e"
                          }
                        ]
                      },
                      {
                        "featureType": "administrative.locality",
                        "elementType": "labels.text.fill",
                        "stylers": [
                          {
                            "color": "#d59563"
                          }
                        ]
                      },
                      {
                        "featureType": "poi",
                        "elementType": "labels.text.fill",
                        "stylers": [
                          {
                            "color": "#d59563"
                          }
                        ]
                      },
                      {
                        "featureType": "poi.park",
                        "elementType": "geometry",
                        "stylers": [
                          {
                            "color": "#263c3f"
                          }
                        ]
                      },
                      {
                        "featureType": "poi.park",
                        "elementType": "labels.text.fill",
                        "stylers": [
                          {
                            "color": "#6b9a76"
                          }
                        ]
                      },
                      {
                        "featureType": "road",
                        "elementType": "geometry",
                        "stylers": [
                          {
                            "color": "#38414e"
                          }
                        ]
                      },
                      {
                        "featureType": "road",
                        "elementType": "geometry.stroke",
                        "stylers": [
                          {
                            "color": "#212a37"
                          }
                        ]
                      },
                      {
                        "featureType": "road",
                        "elementType": "labels.text.fill",
                        "stylers": [
                          {
                            "color": "#9ca5b3"
                          }
                        ]
                      },
                      {
                        "featureType": "road.highway",
                        "elementType": "geometry",
                        "stylers": [
                          {
                            "color": "#746855"
                          }
                        ]
                      },
                      {
                        "featureType": "road.highway",
                        "elementType": "geometry.stroke",
                        "stylers": [
                          {
                            "color": "#1f2835"
                          }
                        ]
                      },
                      {
                        "featureType": "road.highway",
                        "elementType": "labels.text.fill",
                        "stylers": [
                          {
                            "color": "#f3d19c"
                          }
                        ]
                      },
                      {
                        "featureType": "transit",
                        "elementType": "geometry",
                        "stylers": [
                          {
                            "color": "#2f3948"
                          }
                        ]
                      },
                      {
                        "featureType": "transit.station",
                        "elementType": "labels.text.fill",
                        "stylers": [
                          {
                            "color": "#d59563"
                          }
                        ]
                      },
                      {
                        "featureType": "water",
                        "elementType": "geometry",
                        "stylers": [
                          {
                            "color": "#17263c"
                          }
                        ]
                      },
                      {
                        "featureType": "water",
                        "elementType": "labels.text.fill",
                        "stylers": [
                          {
                            "color": "#515c6d"
                          }
                        ]
                      },
                      {
                        "featureType": "water",
                        "elementType": "labels.text.stroke",
                        "stylers": [
                          {
                            "color": "#17263c"
                          }
                        ]
                      }
                    ]
                ''');
  }

  Future<void> getUserCurrentLocation() async {
    await Geolocator.checkPermission();
    await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      forceAndroidLocationManager: true,
    );

    currentPosition = position;

    LatLng pos = LatLng(position.latitude, position.longitude);

    CameraPosition cameraPosition = CameraPosition(target: pos, zoom: 16);
    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(cameraPosition),
    );

    if (userModelCurrentInfo != null) {
      userName = userModelCurrentInfo!.name ?? '';
      userEmail = userModelCurrentInfo!.email ?? '';
    }

    initializeGeoFireListener();
    AssistantMethods.readTripsKeysForOnlineUser(context);
  }

  Future<void> checkIfPermissionAllowed() async {
    _locationPermission = await Geolocator.requestPermission();
    if (_locationPermission == LocationPermission.denied) {
      _locationPermission = await Geolocator.requestPermission();
    }
  }

  void initializeGeoFireListener() {
    Geofire.initialize('activeDrivers');
    Geofire.queryAtLocation(
      currentPosition!.latitude,
      currentPosition!.longitude,
      5,
    )!.listen((map) {
      if (map != null) {
        var callBack = map['callBack'];

        switch (callBack) {
          case Geofire.onKeyEntered:
            ActiveNearbyDrivers activeNearbyDrivers = ActiveNearbyDrivers();
            activeNearbyDrivers.locationLat = map['latitude'];
            activeNearbyDrivers.locationLng = map['longitude'];
            activeNearbyDrivers.driverId = map['key'];
            GeoFireAssistant.activeNearbyDriversList.add(activeNearbyDrivers);
            if (activeNearbyDriverKeysLoaded == true) {
              dispayActiveDriversOnUsersMap();
            }
            break;

          case Geofire.onKeyExited:
            GeoFireAssistant.deleteOfflineDriverfromList(map['key']);
            dispayActiveDriversOnUsersMap();
            break;

          case Geofire.onKeyMoved:
            ActiveNearbyDrivers activeNearbyDrivers = ActiveNearbyDrivers();
            activeNearbyDrivers.locationLat = map['latitude'];
            activeNearbyDrivers.locationLng = map['longitude'];
            activeNearbyDrivers.driverId = map['key'];
            GeoFireAssistant.updateActiveNearbyAvailableDriverLocation(
              activeNearbyDrivers,
            );
            dispayActiveDriversOnUsersMap();
            break;

          case Geofire.onGeoQueryReady:
            activeNearbyDriverKeysLoaded = true;
            dispayActiveDriversOnUsersMap();
            break;
        }
      }

      setState(() {});
    });
  }

  void dispayActiveDriversOnUsersMap() async {
    final Uint8List newIcon = await getMarkerIcon('images/marker.png', 100);
    setState(() {
      markers.clear();
      circles.clear();

      for (ActiveNearbyDrivers eachDrive
          in GeoFireAssistant.activeNearbyDriversList) {
        LatLng eachDriverActivePosition = LatLng(
          eachDrive.locationLat!,
          eachDrive.locationLng!,
        );

        Marker marker = Marker(
          markerId: MarkerId(eachDrive.driverId!),
          position: eachDriverActivePosition,
          icon: BitmapDescriptor.fromBytes(newIcon),
          rotation: 360,
        );
        markers.add(marker);
      }
    });
  }

  Future<Uint8List> getMarkerIcon(String image, int size) async {
    ByteData data = await rootBundle.load(image);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetHeight: size,
    );
    ui.FrameInfo info = await codec.getNextFrame();
    return (await info.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  }

  @override
  void initState() {
    checkIfPermissionAllowed();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    int hour = now.hour;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            GoogleMap(
              key: const ValueKey('main_map'), // ดีมาก มีแล้ว
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: true,
              padding: const EdgeInsets.only(bottom: 20, top: 20),
              mapType: MapType.normal,
              initialCameraPosition: _kGooglePlex,
              markers: markers,
              circles: circles,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
                mapController = controller;

                if (hour >= 6 && hour < 18) {
                  // Day mode
                } else {
                  blackThemeGoogleMap();
                }

                getUserCurrentLocation();
              },
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
            onPressed: () {
              Get.until((route) => route.isFirst);
            },
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
