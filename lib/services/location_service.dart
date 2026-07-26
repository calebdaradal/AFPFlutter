import 'package:geolocator/geolocator.dart'; // added: device location access for scan coordinates

class LocationService {
  Future<({double latitude, double longitude})> getCurrentCoordinates() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled(); // added: check if device location service is on
    if (!serviceEnabled) {
      throw Exception('Location service is disabled.'); // added: stop when GPS/location service is off
    }

    LocationPermission permission = await Geolocator.checkPermission(); // added: read current location permission state
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission(); // added: ask user for location permission if not granted yet
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.'); // added: stop when user denies permission
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is permanently denied.'); // added: stop when permission must be enabled from settings
    }

    final position = await Geolocator.getCurrentPosition( // added: fetch latest device position for scan payload
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, // added: request precise coordinates for scan event
      ),
    );

    return ( // added: return both latitude and longitude together
      latitude: position.latitude, // added: current device latitude
      longitude: position.longitude, // added: current device longitude
    );
  }
}
