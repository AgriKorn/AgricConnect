import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Real current weather for the farmer's region via Open-Meteo — free, no
/// API key required. Used instead of the old hardcoded "28°C, Kumasi" shown
/// to every farmer regardless of where they actually farm.
class WeatherSnapshot {
  const WeatherSnapshot({required this.tempC, required this.icon});

  final double tempC;
  final IconData icon;
}

/// Maps WMO weather codes (Open-Meteo's `weather_code`) to a representative icon.
IconData _iconForWeatherCode(int code) {
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code <= 2) return Icons.wb_cloudy_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code >= 45 && code <= 48) return Icons.cloud_rounded;
  if (code >= 51 && code <= 67) return Icons.grain_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 80 && code <= 82) return Icons.grain_rounded;
  if (code >= 95) return Icons.thunderstorm_rounded;
  return Icons.wb_sunny_rounded;
}

abstract class WeatherRepository {
  Future<WeatherSnapshot> fetchCurrent({required double lat, required double long});
}

class OpenMeteoWeatherRepository implements WeatherRepository {
  final Dio _dio = Dio();

  @override
  Future<WeatherSnapshot> fetchCurrent({required double lat, required double long}) async {
    final response = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': long,
        'current': 'temperature_2m,weather_code',
        'timezone': 'auto',
      },
    );
    final current = response.data['current'] as Map<String, dynamic>? ?? {};
    final tempC = double.tryParse(current['temperature_2m']?.toString() ?? '') ?? 0;
    final code = int.tryParse(current['weather_code']?.toString() ?? '') ?? 0;
    return WeatherSnapshot(tempC: tempC, icon: _iconForWeatherCode(code));
  }
}

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) => OpenMeteoWeatherRepository());
