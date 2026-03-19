import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherApi {
  final String apiKey;
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  WeatherApi(this.apiKey);

  Future<Map<String, dynamic>> fetchWeather(double lat, double lon) async {
    final url = '$_baseUrl?lat=$lat&lon=$lon&units=metric&appid=$apiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch weather data');
    }
  }
}
