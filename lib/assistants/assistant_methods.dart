// ignore_for_file: unused_local_variable, use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:colae_cut/assistants/direction_details_info.dart';
import 'package:colae_cut/assistants/request_menthods.dart';
import 'package:colae_cut/cont/api_key.dart';
import 'package:colae_cut/models/directions.dart';
import 'package:colae_cut/models/trip_history_model.dart';
import 'package:colae_cut/models/user_model.dart';
import 'package:colae_cut/providers/app_info.dart';
import 'package:colae_cut/services/sevice.dart';

class AssistantMethods {
  static Future<String> searchAddressForGeographicCoOrdinates(
    Position position,
    context,
  ) async {
    String apiUrl =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$mapKey';

    String humanReadableAddress = '';
    var reponse = await RequestAssistant.receiveRequest(apiUrl);
    if (reponse != 'Failed.') {
      humanReadableAddress = reponse['results'][0]['formatted_address'];
      Directions userAddress = Directions();
      userAddress.locationLat = position.latitude;
      userAddress.locationLng = position.longitude;
      userAddress.locationName = humanReadableAddress;

      Provider.of<AppInfo>(
        context,
        listen: false,
      ).updateLocationAddress(userAddress);
    }
    return humanReadableAddress;
  }

  static void readCurrentOnlineUerInfo() async {
    currentfuser = auth.currentUser;
    DatabaseReference userRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(currentfuser!.uid);

    userRef.once().then((snap) {
      if (snap.snapshot.value != null) {
        userModelCurrentInfo = UserModel.fromSnpshot(snap.snapshot);
      }
    });
  }

  static Future<DirectionDetailsInfo?>
  obtainOriginToDestinationDirectionDetails(
    LatLng origionPosition,
    LatLng destinationPosition,
  ) async {
    String urlOriginToDestinationDirectionDetails =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origionPosition.latitude},${origionPosition.longitude}&destination=${destinationPosition.latitude},${destinationPosition.longitude}&key=$mapKey';
    var responeDirectionApi = await RequestAssistant.receiveRequest(
      urlOriginToDestinationDirectionDetails,
    );

    if (responeDirectionApi == 'Failed.') {
      return null;
    }

    DirectionDetailsInfo detailsInfo = DirectionDetailsInfo();
    detailsInfo.e_points =
        responeDirectionApi['routes'][0]['overview_polyline']['points'];
    detailsInfo.distance_text =
        responeDirectionApi['routes'][0]['legs'][0]['distance']['text'];
    detailsInfo.distance_value =
        responeDirectionApi['routes'][0]['legs'][0]['distance']['value'];

    detailsInfo.duration_text =
        responeDirectionApi['routes'][0]['legs'][0]['duration']['text'];
    detailsInfo.durtion_value =
        responeDirectionApi['routes'][0]['legs'][0]['duration']['value'];

    return detailsInfo;
  }

  static double calculateFareAmountFromOringintoDestination(
    DirectionDetailsInfo detailsInfo,
  ) {
    double timeTraveledFarePerMinute = (detailsInfo.durtion_value! / 60) * 7;
    double distancetraveledFareAmountPerKilometer =
        (detailsInfo.durtion_value! / 1000) * 7;

    double totalFareAmount =
        timeTraveledFarePerMinute + distancetraveledFareAmountPerKilometer;

    return double.parse(totalFareAmount.toStringAsFixed(2));
  }

  static Future<void> sendNotificationToDriverNow(
    String deviceRegistrationToken,
    String userRideRequestId,
    BuildContext context,
  ) async {
    String destinationAddress = userDropOffAdress;
    Map<String, String> headerNotification = {
      'Content-Type': 'application/json',
      'Authorization': cloudMessagingServerToken,
    };
    Map bodyNotification = {
      "body": "Destination Address: \n$destinationAddress.",
      "title": "New Trip Request",
    };

    Map dataMap = {
      "click_action": "FLUTTER_NOTIFICATION_CLICK",
      "id": "1",
      "status": "done",
      "rideRequestId": userRideRequestId,
    };

    Map officialNotificationFormat = {
      "notification": bodyNotification,
      "data": dataMap,
      "priority": "high",
      "to": deviceRegistrationToken,
    };
    var responseNotification = http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: headerNotification,
      body: jsonEncode(officialNotificationFormat),
    );
  }

  static void readTripsKeysForOnlineUser(BuildContext context) {
    FirebaseDatabase.instance
        .ref()
        .child('rideRequests')
        .orderByChild('userName')
        .equalTo(userModelCurrentInfo!.name)
        .once()
        .then((snap) {
          if (snap.snapshot.value != null) {
            Map keysTripsId = snap.snapshot.value as Map;
            int overAllTripsCounter = keysTripsId.length;
            Provider.of<AppInfo>(
              context,
              listen: false,
            ).updateOverAllTripsCounter(overAllTripsCounter);
            List<String> tripsKeysList = [];
            keysTripsId.forEach((key, value) {
              tripsKeysList.add(key);
            });
            Provider.of<AppInfo>(
              context,
              listen: false,
            ).updateOverAllTripsKeys(tripsKeysList);
            readTripsHistoryInformation(context);
          }
        });
  }

  static void readTripsHistoryInformation(BuildContext context) {
    var tripsAllKeys = Provider.of<AppInfo>(
      context,
      listen: false,
    ).historyTripKeysList;
    for (String eachKey in tripsAllKeys) {
      FirebaseDatabase.instance
          .ref()
          .child('rideRequests')
          .child(eachKey)
          .once()
          .then((snap) {
            var historyTrips = TripHistoryModel.fromSnapshot(snap.snapshot);

            if ((snap.snapshot.value as Map)['status'] == 'ended') {
              Provider.of<AppInfo>(
                context,
                listen: false,
              ).updateOverAllTripsHistoryInformation(historyTrips);
            }
          });
    }
  }
}
