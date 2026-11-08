import 'dart:math' as math;

String formatEventDate(DateTime dateTime) {
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.day} ${months[dateTime.month - 1]} · $hour:$minute';
}

double distanceKm(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const earthRadiusKm = 6371.0;
  final latitudeDelta = _radians(latitude2 - latitude1);
  final longitudeDelta = _radians(longitude2 - longitude1);
  final a =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(_radians(latitude1)) *
          math.cos(_radians(latitude2)) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;
