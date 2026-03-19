import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../theme/app_theme.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with TickerProviderStateMixin {
  static const String _apiKey = 'c48f457ff8f25f582ee4cc1cc45ea267';
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  String _currentAddress = 'Locating...';
  Position? _currentPosition;
  bool _loading = true;
  double? _temperature;
  String? _description;
  String? _iconCode;
  String? _error;
  int? _humidity;
  double? _windSpeed;

  late AnimationController _loadingController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _determinePosition();
  }

  void _initializeAnimations() {
    _loadingController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _updateError('Location services disabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _updateError('Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _updateError('Location permissions permanently denied');
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
      await _getAddress(position);
      await _fetchWeather();
    }
  }

  Future<void> _getAddress(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress =
              '${place.locality ?? ''}, ${place.administrativeArea ?? ''}';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress =
              '${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchWeather() async {
    if (_currentPosition == null) {
      _updateError('Location not available');
      return;
    }

    final lat = _currentPosition!.latitude;
    final lon = _currentPosition!.longitude;
    final url = '$_baseUrl?lat=$lat&lon=$lon&units=metric&appid=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _temperature = data['main']['temp']?.toDouble();
          _description = data['weather'][0]['description']
              ?.toString()
              .toUpperCase();
          _iconCode = data['weather'][0]['icon'];
          _humidity = data['main']['humidity']?.toInt();
          _windSpeed = data['wind']['speed']?.toDouble();
          _loading = false;
          _error = null;
          _loadingController.forward();
        });
      } else {
        _updateError('Weather service unavailable');
      }
    } catch (e) {
      _updateError('No internet connection');
    }
  }

  void _updateError(String message) {
    if (mounted) {
      setState(() {
        _error = message;
        _loading = false;
      });
    }
  }

  Widget _buildWeatherCard() {
    if (_loading) {
      return Container(
        height: 200, // ✅ Fixed smaller height
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryGreen.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(height: 16),
              Text(
                'Getting your weather...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        height: 200, // ✅ Fixed smaller height
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade50, Colors.orange.shade50],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min, // ✅ CRITICAL: Prevents overflow
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!, // ✅ Short error messages
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 14, // ✅ Smaller font
                  ),
                  maxLines: 2, // ✅ Limit lines
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _determinePosition,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 200, // ✅ Fixed height
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_getWeatherGradient()[0], _getWeatherGradient()[1]],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildWeatherIcon(),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _description ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_temperature?.toStringAsFixed(1) ?? 'N/A'}°',
                    style: const TextStyle(
                      fontSize: 42, // ✅ Slightly smaller
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _currentAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getWeatherGradient() {
    if (_iconCode == null) return [AppTheme.primaryGreen, Colors.blue];

    switch (_iconCode![2]) {
      case 'd':
        return [Colors.orange.shade400, Colors.yellow.shade400];
      case 'n':
        return [Colors.indigo.shade600, Colors.blue.shade700];
      default:
        return [AppTheme.primaryGreen, Colors.blue];
    }
  }

  Widget _buildWeatherIcon() {
    if (_iconCode == null) {
      return Icon(Icons.cloud_outlined, size: 70, color: Colors.white70);
    }

    String iconUrl = 'https://openweathermap.org/img/wn/$_iconCode@4x.png';
    return Image.network(
      iconUrl,
      width: 70,
      height: 70,
      errorBuilder: (context, error, stack) =>
          Icon(_getIconForCode(_iconCode!), size: 70, color: Colors.white),
    );
  }

  IconData _getIconForCode(String code) {
    switch (code[0]) {
      case '01':
        return Icons.wb_sunny;
      case '02':
        return Icons.cloud;
      case '03':
        return Icons.cloud_outlined;
      case '04':
        return Icons.cloud;
      case '09':
        return Icons.cloud_queue;
      case '10':
        return Icons.umbrella;
      case '11':
        return Icons.bolt;
      case '13':
        return Icons.ac_unit;
      case '50':
        return Icons.water_drop;
      default:
        return Icons.cloud_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Weather & Advisory',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryGreen,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryGreen, AppTheme.primaryDarkGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _determinePosition,
        color: AppTheme.primaryGreen,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeatherCard(),
              const SizedBox(height: 24),

              // ✅ Stats only when data available
              if (_temperature != null &&
                  (_humidity != null || _windSpeed != null))
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _WeatherStat(
                          icon: Icons.water_drop,
                          label: 'Humidity',
                          value: '${_humidity ?? 0}%',
                        ),
                      ),
                      if (_windSpeed != null) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: _WeatherStat(
                            icon: Icons.air,
                            label: 'Wind',
                            value: '${_windSpeed!.toStringAsFixed(1)} m/s',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              Text(
                'Today\'s Advisory',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              _AdvisoryTile(
                title: 'Irrigation',
                body: _temperature != null
                    ? (_temperature! < 25
                          ? '💧 Light irrigation recommended'
                          : '✅ Soil moisture adequate')
                    : 'Check soil moisture before watering',
              ),
              const SizedBox(height: 12),

              _AdvisoryTile(
                title: 'Disease Risk',
                body: _humidity != null
                    ? (_humidity! > 70
                          ? '⚠️ High humidity - monitor fungal diseases'
                          : '✅ Low risk period')
                    : 'Monitor plant health regularly',
              ),
              const SizedBox(height: 12),

              _AdvisoryTile(
                title: 'Pest Alert',
                body: '🐛 No major pest outbreaks reported in your region',
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Weather data powered by OpenWeatherMap',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ Other classes remain the same...
class _AdvisoryTile extends StatelessWidget {
  final String title;
  final String body;

  const _AdvisoryTile({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.eco_outlined,
              color: AppTheme.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
