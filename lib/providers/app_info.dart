import 'package:flutter/material.dart';
import 'package:colae_cut/models/directions.dart';
import 'package:colae_cut/models/trip_history_model.dart';

class AppInfo extends ChangeNotifier {
  Directions? userLocation, userDropOffLocation;
  int countTotaltrip = 0;
  List<String> historyTripKeysList = [];
  List<TripHistoryModel> allhistoryInformationList = [];

  void updateLocationAddress(Directions userAddress) {
    if (userLocation == userAddress) return;
    userLocation = userAddress;
    notifyListeners();
  }

  void updateDropOffLocationAddress(Directions dropOffAddress) {
    if (userDropOffLocation == dropOffAddress) return;
    userDropOffLocation = dropOffAddress;
    notifyListeners();
  }

  void updateOverAllTripsCounter(int overAllTripsCounter) {
    if (countTotaltrip == overAllTripsCounter) return;
    countTotaltrip = overAllTripsCounter;
    notifyListeners();
  }

  void updateOverAllTripsKeys(List<String> tripKeysList) {
    historyTripKeysList = tripKeysList;
    notifyListeners();
  }

  void updateOverAllTripsHistoryInformation(TripHistoryModel historyTrips) {
    allhistoryInformationList.add(historyTrips);
    notifyListeners();
  }
}
