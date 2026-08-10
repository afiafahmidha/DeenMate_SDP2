import 'dart:convert';

import 'package:http/http.dart' as http;

class EmergencyWeatherData {
  const EmergencyWeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.weatherCode,
    required this.cloudCover,
    required this.isDay,
    required this.precipitation,
    required this.windSpeed,
    required this.sunrise,
    required this.sunset,
  });

  final double temperature;
  final double feelsLike;
  final int weatherCode;
  final int cloudCover;
  final bool isDay;
  final double precipitation;
  final double windSpeed;
  final DateTime? sunrise;
  final DateTime? sunset;

  bool get isRainy => precipitation > 0 || weatherCode >= 51;
  bool get isCloudy => cloudCover >= 45 || weatherCode.isBetween(1, 3);
}

extension on int {
  bool isBetween(int min, int max) => this >= min && this <= max;
}

class WeatherService {
  WeatherService._();
  static final instance = WeatherService._();

  Future<EmergencyWeatherData> current(double latitude, double longitude) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$latitude', 'longitude': '$longitude',
      'current': 'temperature_2m,apparent_temperature,weather_code,cloud_cover,is_day,precipitation,wind_speed_10m',
      'daily': 'sunrise,sunset', 'forecast_days': '1', 'timezone': 'auto',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw StateError('Weather service returned ${response.statusCode}.');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>?;
    DateTime? parseDaily(String key) {
      final values = daily?[key] as List<dynamic>?;
      return values?.isNotEmpty == true ? DateTime.tryParse(values!.first as String) : null;
    }
    return EmergencyWeatherData(
      temperature: (current['temperature_2m'] as num).toDouble(),
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      weatherCode: current['weather_code'] as int,
      cloudCover: current['cloud_cover'] as int,
      isDay: current['is_day'] == 1,
      precipitation: (current['precipitation'] as num).toDouble(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      sunrise: parseDaily('sunrise'),
      sunset: parseDaily('sunset'),
    );
  }
}
