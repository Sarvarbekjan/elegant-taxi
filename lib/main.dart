import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElegantTaxiApp());
}

// ==================== GLOBAL BAZA ====================
class OrderModel {
  final String id;
  final String clientPhone;
  final String fromAddress;
  final String toAddress;
  final LatLng fromPoint;
  final LatLng toPoint;
  final String tariff;
  final double distanceKm;
  final int price;
  String status;
  String? driverName;
  String? driverCar;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.clientPhone,
    required this.fromAddress,
    required this.toAddress,
    required this.fromPoint,
    required this.toPoint,
    required this.tariff,
    required this.distanceKm,
    required this.price,
    this.status = 'Kutilmoqda',
    this.driverName,
    this.driverCar,
    required this.createdAt,
  });
}

class DriverModel {
  String id;
  String name;
  String phone;
  String carModel;
  String carNumber;
  int balance;
  bool isOnline;
  bool isBlocked;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.carModel,
    required this.carNumber,
    this.balance = 50000,
    this.isOnline = true,
    this.isBlocked = false,
  });
}

class AppState extends ChangeNotifier {
  int baseFare = 4000;
  int perKmRate = 2000;
  double comfortMultiplier = 1.35;
  int deliveryExtra = 3000;
  int commissionPercent = 10;

  final String adminPass = "9728847";
  bool isAdminUnlocked = false;

  List<OrderModel> orders = [];
  List<DriverModel> drivers = [
    DriverModel(
      id: "D1",
      name: "Sardor Aliyev",
      phone: "+998 90 123 45 67",
      carModel: "Oq Cobalt",
      carNumber: "01 A 777 AA",
      balance: 85000,
      isOnline: true,
    ),
  ];

  void updateTariffs({required int newBase, required int newPerKm, required int newComm}) {
    baseFare = newBase;
    perKmRate = newPerKm;
    commissionPercent = newComm;
    notifyListeners();
  }

  void createOrder(OrderModel order) {
    orders.insert(0, order);
    notifyListeners();
  }

  void acceptOrder(String orderId, DriverModel driver) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      orders[idx].status = 'Qabul qilindi';
      orders[idx].driverName = driver.name;
      orders[idx].driverCar = "${driver.carModel} (${driver.carNumber})";
      notifyListeners();
    }
  }

  void completeOrder(String orderId, DriverModel driver) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1 && orders[idx].status != 'Yakunlandi') {
      orders[idx].status = 'Yakunlandi';
      int comm = ((orders[idx].price * commissionPercent) / 100).round();
      driver.balance -= comm;
      notifyListeners();
    }
  }

  void cancelOrder(String orderId) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      orders[idx].status = 'Bekor qilindi';
      notifyListeners();
    }
  }

  void addDriver(DriverModel d) {
    drivers.add(d);
    notifyListeners();
  }

  void toggleDriverBlock(String id) {
    final idx = drivers.indexWhere((d) => d.id == id);
    if (idx != -1) {
      drivers[idx].isBlocked = !drivers[idx].isBlocked;
      notifyListeners();
    }
  }

  void addDriverBalance(String id, int amount) {
    final idx = drivers.indexWhere((d) => d.id == id);
    if (idx != -1) {
      drivers[idx].balance += amount;
      notifyListeners();
    }
  }

  int get totalCompletedRevenue => orders.where((o) => o.status == 'Yakunlandi').fold(0, (sum, o) => sum + o.price);
  int get totalCompanyProfit => ((totalCompletedRevenue * commissionPercent) / 100).round();
}

final AppState appState = AppState();

// ==================== ASOSIY ILOVA ====================
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
      home: const RoleContainerScreen(),
    );
  }
}

class RoleContainerScreen extends StatefulWidget {
  const RoleContainerScreen({super.key});

  @override
  State<RoleContainerScreen> createState() => _RoleContainerScreenState();
}

class _RoleContainerScreenState extends State<RoleContainerScreen> {
  int _selectedRole = 0;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _selectRole(int roleIndex) {
    Navigator.pop(context);
    if (roleIndex == 3 && !appState.isAdminUnlocked) {
      _showAdminPasswordDialog();
    } else {
      setState(() => _selectedRole = roleIndex);
    }
  }

  void _showAdminPasswordDialog() {
    final TextEditingController passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: Color(0xFFFFCC00)),
            SizedBox(width: 8),
            Text("Admin Boshqaruv"),
          ],
        ),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: "Parolni kiriting (9728847)",
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Bekor qilish", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFCC00),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (passCtrl.text.trim() == appState.adminPass) {
                appState.isAdminUnlocked = true;
                Navigator.pop(ctx);
                setState(() => _selectedRole = 3);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Parol noto'g'ri!"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("KIRISH", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String roleTitle = "🚖 ELEGANT TAXI";
    if (_selectedRole == 1) roleTitle = "🛞 HAYDOVCHI TERMINALI";
    if (_selectedRole == 2) roleTitle = "🎧 OPERATOR PANELI";
    if (_selectedRole == 3) roleTitle = "👑 SUPER-ADMIN (9728847)";

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF14171F),
        iconTheme: const IconThemeData(color: Color(0xFFFFCC00)),
        title: Text(
          roleTitle,
          style: const TextStyle(color: Color(0xFFFFCC00), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          if (_selectedRole != 0)
            TextButton.icon(
              onPressed: () => setState(() => _selectedRole = 0),
              icon: const Icon(Icons.person, color: Colors.white, size: 18),
              label: const Text("Mijoz", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 50, bottom: 24, left: 20, right: 20),
              color: const Color(0xFF14171F),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFFFCC00),
                    child: Icon(Icons.local_taxi, size: 34, color: Colors.black),
                  ),
                  SizedBox(height: 12),
                  Text("ELEGANT TAXI", style: TextStyle(color: Color(0xFFFFCC00), fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("Yagona boshqaruv tizimi", style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.blue),
              title: const Text("Mijoz (Taksi chaqirish)", style: TextStyle(fontWeight: FontWeight.w600)),
              selected: _selectedRole == 0,
              onTap: () => _selectRole(0),
            ),
            ListTile(
              leading: const Icon(Icons.drive_eta, color: Colors.green),
              title: const Text("Haydovchi rejimi", style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text("${appState.orders.where((o) => o.status == 'Kutilmoqda').length} ta yangi buyurtma"),
              selected: _selectedRole == 1,
              onTap: () => _selectRole(1),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.orange),
              title: const Text("Operator (Dispetcher)", style: TextStyle(fontWeight: FontWeight.w600)),
              selected: _selectedRole == 2,
              onTap: () => _selectRole(2),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
              title: const Text("Super-Admin (Rahbar)", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Parol: 9728847"),
              selected: _selectedRole == 3,
              onTap: () => _selectRole(3),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedRole,
        children: const [
          ClientView(),
          DriverView(),
          OperatorView(),
          AdminView(),
        ],
      ),
    );
  }
}

// ==================== 1. MIJOZ EKRANI ====================
class ClientView extends StatefulWidget {
  const ClientView({super.key});

  @override
  State<ClientView> createState() => _ClientViewState();
}

class _ClientViewState extends State<ClientView> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(41.311081, 69.240562);
  LatLng? _destinationLocation;

  final TextEditingController _fromController = TextEditingController(text: "Mening joylashuvim (GPS)");
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(text: "+998 ");

  String _selectedTariff = 'Ekonom';
  double _distanceKm = 0.0;
  int _orderPrice = 4000;
  OrderModel? _activeOrder;

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
      });
      _mapController.move(_currentLocation, 15);
    } catch (_) {}
  }

  void _calculatePrice() {
    if (_destinationLocation == null) {
      setState(() => _orderPrice = appState.baseFare);
      return;
    }

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

    double rawPrice = appState.baseFare + (dist * appState.perKmRate);
    if (_selectedTariff == 'Komfort') rawPrice *= appState.comfortMultiplier;
    if (_selectedTariff == 'Dostavka') rawPrice += appState.deliveryExtra;

    setState(() {
      _distanceKm = double.parse(dist.toStringAsFixed(1));
      _orderPrice = (rawPrice / 500).round() * 500;
    });
  }

  void _submitOrder() {
    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Iltimos, boradigan manzilni xaritadan bosing!")),
      );
      return;
    }

    final newOrder = OrderModel(
      id: "ORD-${Random().nextInt(9000) + 1000}",
      clientPhone: _phoneController.text.trim(),
      fromAddress: _fromController.text.trim(),
      toAddress: _toController.text.trim().isEmpty ? "Xaritadan tanlangan manzil" : _toController.text.trim(),
      fromPoint: _currentLocation,
      toPoint: _destinationLocation!,
      tariff: _selectedTariff,
      distanceKm: _distanceKm,
      price: _orderPrice,
      createdAt: DateTime.now(),
    );

    appState.createOrder(newOrder);
    setState(() => _activeOrder = newOrder);
  }

  @override
  Widget build(BuildContext context) {
    _calculatePrice();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 14.5,
            onTap: (tapPosition, point) {
              if (_activeOrder == null || _activeOrder!.status == 'Yakunlandi' || _activeOrder!.status == 'Bekor qilindi') {
                setState(() {
                  _destinationLocation = point;
                  _toController.text = "Manzil: ${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}";
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
            if (_destinationLocation != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_currentLocation, _destinationLocation!],
                    strokeWidth: 5.0,
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation,
                  width: 44,
                  height: 44,
                  child: const Icon(Icons.my_location, color: Colors.blue, size: 36),
                ),
                if (_destinationLocation != null)
                  Marker(
                    point: _destinationLocation!,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 42),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            backgroundColor: const Color(0xFF14171F),
            onPressed: _determinePosition,
            child: const Icon(Icons.gps_fixed, color: Color(0xFFFFCC00)),
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
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16)],
            ),
            child: _buildBottomPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    if (_activeOrder != null && _activeOrder!.status != 'Bekor qilindi' && _activeOrder!.status != 'Yakunlandi') {
      bool accepted = _activeOrder!.status == 'Qabul qilindi';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(accepted ? Icons.local_taxi : Icons.radar, size: 46, color: accepted ? Colors.green : const Color(0xFFFFCC00)),
          const SizedBox(height: 8),
          Text(accepted ? "Haydovchi yo'lga chiqdi!" : "Haydovchi qidirilmoqda...", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 6),
          if (accepted)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text("Haydovchi: ${_activeOrder!.driverName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Mashina: ${_activeOrder!.driverCar
