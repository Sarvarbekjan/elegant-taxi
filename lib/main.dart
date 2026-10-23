import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElegantTaxiApp());
}

// ==================== GLOBAL TIZIM BAZASI ====================
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
  String status; // 'Kutilmoqda', 'Qabul qilindi', 'Yakunlandi', 'Bekor qilindi'
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
  // Tarif sozlamalari (Admin o'zgartira oladi)
  int baseFare = 4000;
  int perKmRate = 2000;
  double comfortMultiplier = 1.35;
  int deliveryExtra = 3000;
  int commissionPercent = 10; // 10% xizmat haqi

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
    DriverModel(
      id: "D2",
      name: "Jasur Karimov",
      phone: "+998 93 987 65 43",
      carModel: "Qora Gentra",
      carNumber: "75 Z 555 ZZ",
      balance: 42000,
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

  int get totalCompletedRevenue {
    return orders
        .where((o) => o.status == 'Yakunlandi')
        .fold(0, (sum, o) => sum + o.price);
  }

  int get totalCompanyProfit {
    return ((totalCompletedRevenue * commissionPercent) / 100).round();
  }
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
  int _selectedRole = 0; // 0: Mijoz, 1: Haydovchi, 2: Operator, 3: Admin

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
    Navigator.pop(context); // Drawerni yopish
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
            hintText: "Maxfiy parolni kiriting",
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
                  const SnackBar(
                    content: Text("Parol noto'g'ri! Ruxsat berilmadi."),
                    backgroundColor: Colors.red,
                  ),
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
    if (_selectedRole == 3) roleTitle = "👑 SUPER-ADMIN BOSHQARUV";

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
                  Text(
                    "ELEGANT TAXI",
                    style: TextStyle(color: Color(0xFFFFCC00), fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Yagona avtomatlashtirilgan tizim",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
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
              title: const Text("Haydovchi (Shofyor) rejimi", style: TextStyle(fontWeight: FontWeight.w600)),
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
              subtitle: const Text("Himoyalangan boshqaruv paneli"),
              selected: _selectedRole == 3,
              onTap: () => _selectRole(3),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Elegant Taxi v2.0 Pro", style: TextStyle(color: Colors.grey)),
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

  final List<Map<String, dynamic>> _quickPlaces = [
    {"name": "Markaziy Bozor", "lat": 41.3250, "lng": 69.2450},
    {"name": "Temir yo'l vokzali", "lat": 41.2950, "lng": 69.2850},
    {"name": "Aeroport", "lat": 41.2620, "lng": 69.2650},
    {"name": "Shifoxona", "lat": 41.3320, "lng": 69.2200},
  ];

  @override
  void initState() {
    super.initState();
    _orderPrice = appState.baseFare;
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
      if (permission == LocationPermission.deniedForever) return;

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
    if (_destinationLocation == null && _toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Iltimos, boradigan manzilni xaritadan bosing yoki yozing!")),
      );
      return;
    }

    final destPoint = _destinationLocation ??
        LatLng(_currentLocation.latitude + 0.015, _currentLocation.longitude + 0.015);

    if (_distanceKm == 0.0) {
      _destinationLocation = destPoint;
      _calculatePrice();
    }

    final newOrder = OrderModel(
      id: "ORD-${Random().nextInt(9000) + 1000}",
      clientPhone: _phoneController.text.trim(),
      fromAddress: _fromController.text.trim(),
      toAddress: _toController.text.trim().isEmpty ? "Xaritadan belgilangan nuqta" : _toController.text.trim(),
      fromPoint: _currentLocation,
      toPoint: destPoint,
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
                  _toController.text = "Manzil (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})";
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
          Icon(
            accepted ? Icons.local_taxi : Icons.radar,
            size: 46,
            color: accepted ? Colors.green : const Color(0xFFFFCC00),
          ),
          const SizedBox(height: 8),
          Text(
            accepted ? "Haydovchi yo'lga chiqdi!" : "Yaqin atrofdagi haydovchi qidirilmoqda...",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 6),
          if (accepted)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text("Haydovchi: ${_activeOrder!.driverName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Mashina: ${_activeOrder!.driverCar}", style: const TextStyle(color: Colors.black87)),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "Maslahat: Yon menyudan 'Haydovchi rejimi'ga o'tib, ushbu buyurtmani o'zingiz qabul qilib sinab ko'rishingiz mumkin!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          Text("Narxi: ${_activeOrder!.price} so'm (${_activeOrder!.tariff})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                appState.cancelOrder(_activeOrder!.id);
                setState(() => _activeOrder = null);
              },
              child: const Text("Buyurtmani bekor qilish", style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _quickPlaces.map((place) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                child: ActionChip(
                  avatar: const Icon(Icons.place, size: 16, color: Colors.red),
                  label: Text(place["name"]),
                  onPressed: () {
                    LatLng pt = LatLng(place["lat"], place["lng"]);
                    setState(() {
                      _destinationLocation = pt;
                      _toController.text = place["name"];
                    });
                    _mapController.move(pt, 14);
                    _calculatePrice();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        TextField(
          controller: _fromController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.my_location, color: Colors.green, size: 18),
            hintText: "Qayerdan olamiz?",
            isDense: true,
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
            hintText: "Qayerga boramiz? (Xaritadan bosing)",
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.phone, color: Colors.blue, size: 18),
            hintText: "Telefon raqamingiz",
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Masofa: $_distanceKm km", style: const TextStyle(color: Colors.grey, fontSize: 15)),
            Text("$_orderPrice so'm", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFCC00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _submitOrder,
            child: const Text("BUYURTMA BERISH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

// ==================== 2. HAYDOVCHI (SHOFYOR) PANELI ====================
class DriverView extends StatefulWidget {
  const DriverView({super.key});

  @override
  State<DriverView> createState() => _DriverViewState();
}

class _DriverViewState extends State<DriverView> {
  DriverModel get currentDriver => appState.drivers.first;

  @override
  Widget build(BuildContext context) {
    final pendingOrders = appState.orders.where((o) => o.status == 'Kutilmoqda').toList();
    final myActiveOrders = appState.orders.where((o) => o.status == 'Qabul qilindi' && o.driverName == currentDriver.name).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF14171F),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currentDriver.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text("${currentDriver.carModel} • ${currentDriver.carNumber}", style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text("Balans: ${currentDriver.balance} so'm", style: const TextStyle(color: Color(0xFFFFCC00), fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Switch(
                  value: currentDriver.isOnline,
                  activeColor: Colors.green,
                  onChanged: (v) => setState(() => currentDriver.isOnline = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (currentDriver.isBlocked)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
              child: const Text("Sizning profilingiz Admin tomonidan bloklangan!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            )
          else ...[
            if (myActiveOrders.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Faol buyurtmangiz:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 8),
              ...myActiveOrders.map((ord) => Card(
                    color: Colors.green.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Mijoz tel: ${ord.clientPhone}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("Qayerdan: ${ord.fromAddress}"),
                          Text("Qayerga: ${ord.toAddress}"),
                          Text("Narxi: ${ord.price} so'm (${ord.distanceKm} km)", style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => appState.completeOrder(ord.id, currentDriver),
                              icon: const Icon(Icons.check_circle),
                              label: const Text("SAFARNI YAKUNLASH"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              const Divider(height: 24),
            ],
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Yangi tushgan buyurtmalar:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: pendingOrders.isEmpty
                  ? const Center(child: Text("Hozircha yangi buyurtmalar yo'q...", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: pendingOrders.length,
                      itemBuilder: (ctx, i) {
                        final ord = pendingOrders[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Chip(label: Text(ord.tariff), backgroundColor: const Color(0xFFFFFBEB)),
                                    Text("${ord.price} so'm", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                  ],
                                ),
                                Text("📍 Qayerdan: ${ord.fromAddress}"),
                                Text("🏁 Qayerga: ${ord.toAddress}"),
                                Text("📞 Tel: ${ord.clientPhone} • Masofa: ${ord.distanceKm} km", style: const TextStyle(color: Colors.grey)),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFCC00),
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: () => appState.acceptOrder(ord.id, currentDriver),
                                    child: const Text("QABUL QILISH", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== 3. OPERATOR (DISPETCHER) PANELI ====================
class OperatorView extends StatefulWidget {
  const OperatorView({super.key});

  @override
  State<OperatorView> createState() => _OperatorViewState();
}

class _OperatorViewState extends State<OperatorView> {
  final TextEditingController _phoneCtrl = TextEditingController(text: "+998 ");
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _kmCtrl = TextEditingController(text: "3.0");
  String _tariff = 'Ekonom';

  void _createManualOrder() {
    if (_fromCtrl.text.isEmpty || _toCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Manzillarni kiriting!")),
      );
      return;
    }
    double km = double.tryParse(_kmCtrl.text) ?? 3.0;
    double raw = appState.baseFare + (km * appState.perKmRate);
    if (_tariff == 'Komfort') raw *= appState.comfortMultiplier;
    if (_tariff == 'Dostavka') raw += appState.deliveryExtra;
    int price = (raw / 500).round() * 500;

    final ord = OrderModel(
      id: "OP-${Random().nextInt(9000) + 1000}",
      clientPhone: _phoneCtrl.text.trim(),
      fromAddress: _fromCtrl.text.trim(),
      toAddress: _toCtrl.text.trim(),
      fromPoint: const LatLng(41.311081, 69.240562),
      toPoint: const LatLng(41.321081, 69.250562),
      tariff: _tariff,
      distanceKm: km,
      price: price,
      createdAt: DateTime.now(),
    );

    appState.createOrder(ord);
    _fromCtrl.clear();
    _toCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Buyurtma bazaga qo'shildi va haydovchilarga yuborildi!"), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("📞 Yangi qo'ng'iroq buyurtmasini kiritish", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: "Mijoz telefoni", isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fromCtrl,
                          decoration: const InputDecoration(labelText: "Qayerdan", isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _toCtrl,
                          decoration: const InputDecoration(labelText: "Qayerga", isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _kmCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Taxminiy masofa (km)", isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _tariff,
                        items: ['Ekonom', 'Komfort', 'Dostavka']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _tariff = v!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCC00), foregroundColor: Colors.black),
                      onPressed: _createManualOrder,
                      icon: const Icon(Icons.send),
                      label: const Text("BUYURTMANI YUBORISH", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text("Barcha joriy buyurtmalar nazorati:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Expanded(
            child: appState.orders.isEmpty
                ? const Center(child: Text("Buyurtmalar tarixi bo'sh"))
                : ListView.builder(
                    itemCount: appState.orders.length,
                    itemBuilder: (ctx, i) {
                      final o = appState.orders[i];
                      return Card(
                        child: ListTile(
                          title: Text("${o.fromAddress} ➔ ${o.toAddress}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Tel: ${o.clientPhone} • ${o.price} so'm • Holati: ${o.status}\nHaydovchi: ${o.driverName ?? 'Biriktirilmagan'}"),
                          isThreeLine: true,
                          trailing: o.status == 'Kutilmoqda'
                              ? PopupMenuButton<DriverModel>(
                                  icon: const Icon(Icons.person_add, color: Colors.blue),
                                  onSelected: (d) => appState.acceptOrder(o.id, d),
                                  itemBuilder: (ctx) => appState.drivers
                                      .map((d) => PopupMenuItem(value: d, child: Text("${d.name}ga biriktirish")))
                                      .toList(),
                                )
                              : const Icon(Icons.check_circle, color: Colors.green),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==================== 4. SUPER-ADMIN (RAHBAR) PANELI ====================
class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  late TextEditingController _baseCtrl;
  late TextEditingController _kmCtrl;
  late TextEditingController _commCtrl;

  @override
  void initState() {
    super.initState();
    _baseCtrl = TextEditingController(text: appState.baseFare.toString());
    _kmCtrl = TextEditingController(text: appState.perKmRate.toString());
    _commCtrl = TextEditingController(text: appState.commissionPercent.toString());
  }

  void _saveTariffs() {
    int b = int.tryParse(_baseCtrl.text) ?? 4000;
    int k = int.tryParse(_kmCtrl.text) ?? 2000;
    int c = int.tryParse(_commCtrl.text) ?? 10;
    appState.updateTariffs(newBase: b, newPerKm: k, newComm: c);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Yangi tarif va komissiya saqlandi!"), backgroundColor: Colors.green),
    );
  }

  void _showAddDriverDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: "+998 ");
    final carCtrl = TextEditingController();
    final numCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yangi haydovchi qo'shish"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ism va familiya")),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefon raqami")),
              TextField(controller: carCtrl, decoration: const InputDecoration(labelText: "Mashina rusumi (Oq Cobalt)")),
              TextField(controller: numCtrl, decoration: const InputDecoration(labelText: "Davlat raqami (01 A 777 AA)")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish")),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                appState.addDriver(DriverModel(
                  id: "D${appState.drivers.length + 1}",
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  carModel: carCtrl.text.trim(),
                  carNumber: numCtrl.text.trim(),
                ));
                Navigator.pop(ctx);
              }
            },
            child: const Text("Qo'shish"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard("Jami Buyurtma", "${appState.orders.length} ta", Icons.receipt_long, Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard("Umumiy Aylanma", "${appState.totalCompletedRevenue} so'm", Icons.payments, Colors.green),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard("Kompaniya Foydasi", "${appState.totalCompanyProfit} so'm", Icons.trending_up, Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("⚙️ Tarif va Narxlarni Boshqarish", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _baseCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Boshlang'ich narx (so'm)", border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _kmCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "1 km narxi (so'm)", border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _commCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Komissiya (%)", border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14171F), foregroundColor: const Color(0xFFFFCC00)),
                      onPressed: _saveTariffs,
                      icon: const Icon(Icons.save),
                      label: const Text("TARIFLARNI SAQLASH"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("🚖 Haydovchilar Boshqaruvi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCC00), foregroundColor: Colors.black),
                onPressed: _showAddDriverDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Yangi haydovchi"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...appState.drivers.map((d) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: d.isBlocked ? Colors.red : Colors.green,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text("${d.name} (${d.carNumber})", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${d.carModel} • Tel: ${d.phone}\nBalans: ${d.balance} so'm"),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: "+50,000 so'm balans qo'shish",
                        icon: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                        onPressed: () => appState.addDriverBalance(d.id, 50000),
                      ),
                      IconButton(
                        tooltip: d.isBlocked ? "Blokdan chiqarish" : "Bloklash",
                        icon: Icon(d.isBlocked ? Icons.lock_open : Icons.block, color: Colors.red),
                        onPressed: () => appState.toggleDriverBlock(d.id),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
