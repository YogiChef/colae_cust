import 'package:colae_cut/models/active_nearby_drers.dart';

class GeoFireAssistant {
  static List<ActiveNearbyDrivers> activeNearbyDriversList = [];
  static void deleteOfflineDriverfromList(String driverId) {
    int indexNuber = activeNearbyDriversList.indexWhere(
      (element) => element.driverId == driverId,
    );
    activeNearbyDriversList.removeAt(indexNuber);
  }

  static void updateActiveNearbyAvailableDriverLocation(
    ActiveNearbyDrivers driverWhoMove,
  ) {
    int indexNumber = activeNearbyDriversList.indexWhere(
      (element) => element.driverId == driverWhoMove.driverId,
    );
    activeNearbyDriversList[indexNumber].locationLat =
        driverWhoMove.locationLat;
    activeNearbyDriversList[indexNumber].locationLng =
        driverWhoMove.locationLng;
  }
}
