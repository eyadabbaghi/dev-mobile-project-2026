const eventCityCoordinates = <String, (double, double)>{
  'Tunis': (36.8065, 10.1815),
  'Sousse': (35.8256, 10.63699),
  'Ariana': (36.8665, 10.1945),
};

(double, double)? eventCoordinatesForCity(String city) {
  final normalizedCity = city.trim().toLowerCase();
  for (final entry in eventCityCoordinates.entries) {
    if (entry.key.toLowerCase() == normalizedCity) return entry.value;
  }
  return null;
}
