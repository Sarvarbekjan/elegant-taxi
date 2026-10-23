import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElegantTaxiApp());
}

class ElegantTaxiApp extends StatelessWidget {
  const ElegantTaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elegant Taxi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFFFCC00),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        fontFamily: 'Roboto',
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(37.2242, 67.2783);
  LatLng? _destinationLocation;
  
  final TextEditingController _fromController = TextEditingController(text: "Mening joylashuvim");
  final TextEditingController _toController = TextEditingController();

  String _selectedTariff = 'Ekonom';
  double _distanceKm = 2.5;
  int _orderPrice = 9000;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _mapController.move(_currentLocation, 15);
      });
    } catch (_) {}
  }

  void _calculatePrice() {
    if (_destinationLocation == null) return;

    const double earthRadius = 6371.0;
    double dLat = (_destinationLocation!.latitude - _currentLocation.latitude) * pi / 180;
    double dLon = (_destinationLocation!.longitude - _currentLocation.longitude) * pi / 180;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_currentLocation.latitude * pi / 180) *
            cos(_destinationLocation!.latitude * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double dist = earthRadius * c * 1.3;
    if (dist < 1.0) dist = 1.0;

    int baseFare = 4000;
    int perKm = 2000;
    double rawPrice = baseFare + (dist * perKm);

    if (_selectedTariff == 'Komfort') rawPrice *= 1.3;
    if (_selectedTariff == 'Dostavka') rawPrice += 3000;

    setState(() {
      _distanceKm = double.parse(dist.toStringAsFixed(1));
      _orderPrice = (rawPrice / 500).round() * 500;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15,
              onTap: (tapPosition, point) {
                if (!_isSearching) {
                  setState(() {
                    _destinationLocation = point;
                    _toController.text = "Xaritadan tanlangan manzil";
                  });
                  _calculatePrice();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.elegant.taxi',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    child: const Icon(Icons.my_location, color: Colors.blue, size: 36),
                  ),
                  if (_destinationLocation != null)
                    Marker(
                      point: _destinationLocation!,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF14171F),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: const Row(
                children: [
                  Text("🚖 ELEGANT TAXI", style: TextStyle(color: Color(0xFFFFCC00), fontWeight: FontWeight.bold, fontSize: 16)),
                  Spacer(),
                  Icon(Icons.shield, color: Colors.green, size: 20),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
              ),
              child: _isSearching
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFFFFCC00)),
                        const SizedBox(height: 12),
                        const Text("Haydovchi qidirilmoqda...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => setState(() => _isSearching = false),
                          child: const Text("Bekor qilish", style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _fromController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.circle, color: Colors.green, size: 14),
                            hintText: "Qayerdan olamiz?",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _toController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.location_on, color: Colors.red, size: 18),
                            hintText: "Qayerga? (Xaritadan bosing)",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: ['Ekonom', 'Komfort', 'Dostavka'].map((t) {
                            bool sel = _selectedTariff == t;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedTariff = t);
                                _calculatePrice();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: sel ? const Color(0xFFFFFBEB) : Colors.grey.shade100,
                                  border: Border.all(color: sel ? const Color(0xFFFFCC00) : Colors.transparent, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.black : Colors.grey)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Masofa: $_distanceKm km", style: const TextStyle(color: Colors.grey)),
                            Text("$_orderPrice so'm", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFCC00),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => setState(() => _isSearching = true),
                            child: const Text("BUYURTMA BERISH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
