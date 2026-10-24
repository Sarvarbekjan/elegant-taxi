import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElegantTaxiApp());
}

const String yandexApiKey = "f3f7d5ef-8357-44fe-bf9a-c6ca458c7076";
const Color kBekGreen = Color(0xFF22A038);
const Color kTaxiYellow = Color(0xFFFFCC00);
const Color kDarkBg = Color(0xFF14171F);

// Yandex EPSG:3395 proyeksiyasini aniq GPS nuqtasiga moslashtirish
LatLng wgs84ToYandex(double lat, double lon) {
  const double e = 0.0818191908426;
  final double rad = lat * pi / 180.0;
  final double sinPhi = sin(rad);
  final double y = log(
    tan(pi / 4.0 + rad / 2.0) *
        pow((1.0 - e * sinPhi) / (1.0 + e * sinPhi), e / 2.0),
  );
  final double adjLat = (2.0 * atan(exp(y)) - pi / 2.0) * 180.0 / pi;
  return LatLng(adjLat, lon);
}

// ==================== MODELLAR ====================
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
  String status; // Kutilmoqda, Qabul qilindi, Yetib keldi, Safarda, Yakunlandi, Bekor qilindi
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
  String tariffType;
  int trips;
  int balance;
  bool isOnline;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.carModel,
    required this.carNumber,
    this.tariffType = 'STANDART',
    this.trips = 144,
    this.balance = 584200,
    this.isOnline = true,
  });
}

// ==================== GLOBAL HOLAT ====================
class AppState extends ChangeNotifier {
  int stdBase = 4000;
  int stdPerKm = 2000;
  int comfBase = 5000;
  int comfPerKm = 3000;
  int delivBase = 6000;
  int delivPerKm = 2500;
  double commissionPercent = 10.0;

  final String adminPass = "9728847";
  bool isAdminUnlocked = false;
  int clientBonus = 10000;
  bool useBonus = false;

  List<OrderModel> orders = [];
  List<DriverModel> drivers = [
    DriverModel(
      id: "D1",
      name: "Sardor Aliyev",
      phone: "+998 90 123 45 67",
      carModel: "Oq Chevrolet Cobalt",
      carNumber: "01 A 777 AA",
      tariffType: "STANDART",
      trips: 144,
      balance: 584200,
    ),
    DriverModel(
      id: "D2",
      name: "Jasur Karimov",
      phone: "+998 90 987 65 43",
      carModel: "Qora Chevrolet Gentra",
      carNumber: "01 B 555 BB",
      tariffType: "KOMFORT",
      trips: 98,
      balance: 120000,
    ),
    DriverModel(
      id: "D3",
      name: "Bobur Toshmatov",
      phone: "+998 93 555 44 33",
      carModel: "Oq Damas Labo",
      carNumber: "01 D 222 DD",
      tariffType: "DOSTAVKA",
      trips: 78,
      balance: 95000,
    ),
  ];

  void saveTariffs({
    required int sB,
    required int sK,
    required int cB,
    required int cK,
    required int dB,
    required int dK,
    required double comm,
  }) {
    stdBase = sB;
    stdPerKm = sK;
    comfBase = cB;
    comfPerKm = cK;
    delivBase = dB;
    delivPerKm = dK;
    commissionPercent = comm;
    notifyListeners();
  }

  void createOrder(OrderModel order) {
    orders.insert(0, order);
    notifyListeners();
  }

  void updateOrderStatus(String orderId, String newStatus, DriverModel driver) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      orders[idx].status = newStatus;
      orders[idx].driverName = driver.name;
      orders[idx].driverCar = "${driver.carModel} • ${driver.carNumber}";
      if (newStatus == 'Yakunlandi') {
        int comm = ((orders[idx].price * commissionPercent) / 100).round();
        driver.balance -= comm;
        driver.trips += 1;
      }
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

  void addDriverBalance(String id, int amount) {
    final idx = drivers.indexWhere((d) => d.id == id);
    if (idx != -1) {
      drivers[idx].balance += amount;
      notifyListeners();
    }
  }

  void addNewDriver(String name, String car, String num) {
    drivers.add(
      DriverModel(
        id: "D${drivers.length + 1}",
        name: name,
        phone: "+998 90 000 00 00",
        carModel: car,
        carNumber: num,
        balance: 50000,
      ),
    );
    notifyListeners();
  }
}

final AppState appState = AppState();

// ==================== ASOSIY ILOVA ====================
class ElegantTaxiApp extends StatelessWidget {
  const ElegantTaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bek & Elegant Taxi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: kBekGreen,
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
            Icon(Icons.lock, color: kBekGreen),
            SizedBox(width: 8),
            Text("Super-Admin Kirish"),
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
              backgroundColor: kBekGreen,
              foregroundColor: Colors.white,
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
            child: const Text("KIRISH"),
          ),
        ],
      ),
    );
  }

  void _showInfoModal(String title, String body) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(body),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBekGreen, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Yopish"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int pendingCount = appState.orders.where((o) => o.status == 'Kutilmoqda').length;

    String roleTitle = "HAYDOVCHI TERMINALI";
    if (_selectedRole == 2) roleTitle = "OPERATOR MARKAZI";
    if (_selectedRole == 3) roleTitle = "SUPER-ADMIN BOSHQARUVI";

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      appBar: _selectedRole == 0
          ? null
          : AppBar(
              backgroundColor: kDarkBg,
              iconTheme: const IconThemeData(color: kTaxiYellow),
              title: Text(
                roleTitle,
                style: const TextStyle(color: kTaxiYellow, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () => setState(() => _selectedRole = 0),
                  icon: const Icon(Icons.person, color: Colors.white, size: 18),
                  label: const Text("Mijoz", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.green.shade50,
                      child: const Icon(Icons.person_outline, color: kBekGreen, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Sarvarbek",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: kBekGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Bonus: ${appState.clientBonus}",
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16, top: 12, bottom: 4),
                      child: Text(
                        "TIZIM ROLLARI (4 TA REJIM)",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.map, color: kBekGreen),
                      title: const Text("Mijoz (Taksi chaqirish)", style: TextStyle(fontWeight: FontWeight.w600)),
                      selected: _selectedRole == 0,
                      onTap: () => _selectRole(0),
                    ),
                    ListTile(
                      leading: const Icon(Icons.local_taxi, color: Colors.green),
                      title: const Text("Haydovchi rejimi", style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text("$pendingCount ta yangi buyurtma"),
                      trailing: pendingCount > 0
                          ? CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.red,
                              child: Text(
                                "$pendingCount",
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            )
                          : null,
                      selected: _selectedRole == 1,
                      onTap: () => _selectRole(1),
                    ),
                    ListTile(
                      leading: const Icon(Icons.headset_mic, color: Colors.orange),
                      title: const Text("Operator paneli", style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text("Qo'lda buyurtma va nazorat"),
                      selected: _selectedRole == 2,
                      onTap: () => _selectRole(2),
                    ),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings, color: Colors.redAccent),
                      title: const Text("Super-Admin", style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text("Tariflar, haydovchilar va balans"),
                      selected: _selectedRole == 3,
                      onTap: () => _selectRole(3),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.history, color: Colors.grey),
                      title: const Text("Buyurtmalar tarixi"),
                      onTap: () => _showInfoModal(
                        "Buyurtmalar tarixi",
                        "Jami bajarilgan buyurtmalar soni: ${appState.orders.length} ta",
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.favorite_border, color: Colors.grey),
                      title: const Text("Sevimli manzillar"),
                      onTap: () => _showInfoModal("Sevimli manzillar", "Hozircha saqlangan manzillar yo'q."),
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.grey),
                      title: const Text("Kompaniya haqida"),
                      subtitle: const Text("Bek & Elegant Taxi"),
                      onTap: () => _showInfoModal(
                        "Kompaniya haqida",
                        "Elegant & Bek Taxi — Yandex MapKit tizimida ishlovchi zamonaviy taksi xizmati.",
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.support_agent, color: Colors.grey),
                      title: const Text("Qayta aloqa"),
                      onTap: () => _showInfoModal("Qayta aloqa", "Dispetcherlik xizmati: 1413\nTel: +998 90 123 45 67"),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: kBekGreen,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.local_taxi, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "Bek & Elegant Taxi",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedRole,
        children: [
          ClientView(
            onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            onQuickRoleSwitch: (r) => setState(() => _selectedRole = r),
          ),
          const DriverView(),
          const OperatorView(),
          const AdminView(),
        ],
      ),
    );
  }
}

// ==================== 1. MIJOZ EKRANI (BEK TAXI + YANDEX MAP) ====================
class ClientView extends StatefulWidget {
  final VoidCallback onOpenDrawer;
  final ValueChanged<int> onQuickRoleSwitch;

  const ClientView({
    super.key,
    required this.onOpenDrawer,
    required this.onQuickRoleSwitch,
  });

  @override
  State<ClientView> createState() => _ClientViewState();
}

class _ClientViewState extends State<ClientView> {
  final MapController _mapController = MapController();

  LatLng _currentLocation = wgs84ToYandex(37.8267, 67.5975);
  LatLng? _destinationLocation;

  final TextEditingController _fromController = TextEditingController(text: "Baraka Savdo, Qumqo'rg'on");
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(text: "+998 90 267 25 80");

  String _serviceTab = 'Taksi';
  String _selectedTariff = 'Standart';
  double _distanceKm = 0.0;
  int _etaMinutes = 8;
  String _wishNote = "";
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

      Position pos = await Geolocator.getCurrentPosition();
      final LatLng converted = wgs84ToYandex(pos.latitude, pos.longitude);
      setState(() {
        _currentLocation = converted;
        _fromController.text = "Joriy joylashuv (${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)})";
      });
      _mapController.move(_currentLocation, 15.0);
    } catch (_) {}
  }

  int _getTariffPrice(String tariffName) {
    int base = appState.stdBase;
    int perKm = appState.stdPerKm;
    if (tariffName == 'Komfort') {
      base = appState.comfBase;
      perKm = appState.comfPerKm;
    } else if (tariffName == 'Dostavka') {
      base = appState.delivBase;
      perKm = appState.delivPerKm;
    }
    if (_destinationLocation == null || _distanceKm <= 0) {
      return base;
    }
    double raw = base + (_distanceKm * perKm);
    return (raw / 500).round() * 500;
  }

  void _recalculateDistance() {
    if (_destinationLocation == null) {
      setState(() {
        _distanceKm = 0.0;
        _etaMinutes = 8;
      });
      return;
    }
    const double earthRadius = 6371.0;
    double dLat = (_destinationLocation!.latitude - _currentLocation.latitude) * pi / 180.0;
    double dLon = (_destinationLocation!.longitude - _currentLocation.longitude) * pi / 180.0;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_currentLocation.latitude * pi / 180.0) *
            cos(_destinationLocation!.latitude * pi / 180.0) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double dist = earthRadius * c * 1.3;
    if (dist < 1.0) dist = 1.0;

    setState(() {
      _distanceKm = double.parse(dist.toStringAsFixed(1));
      _etaMinutes = max(3, (dist * 1.8).round());
    });
  }

  void _openDestinationSheet() {
    final TextEditingController searchCtrl = TextEditingController(text: _toController.text);
    final List<String> presets = [
      "Markaziy Bozor",
      "Avtoshohbekat",
      "Yangishahar mahallasi",
      "Denov markazi",
      "Temir yo'l vokzali",
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: kBekGreen),
                hintText: "Ko'cha, bino yoki mo'ljalni yozing...",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  setState(() {
                    _toController.text = val.trim();
                    _destinationLocation ??= LatLng(
                      _currentLocation.latitude + 0.015,
                      _currentLocation.longitude + 0.015,
                    );
                  });
                  _recalculateDistance();
                }
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 10),
            const Text("Tezkor manzillar:", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ...presets.map(
              (place) => ListTile(
                dense: true,
                leading: const Icon(Icons.location_on_outlined, color: kBekGreen),
                title: Text(place),
                onTap: () {
                  final double offset = (presets.indexOf(place) + 1) * 0.008;
                  setState(() {
                    _toController.text = place;
                    _destinationLocation = LatLng(
                      _currentLocation.latitude + offset,
                      _currentLocation.longitude + offset,
                    );
                  });
                  _recalculateDistance();
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openWishesDialog() {
    final TextEditingController noteCtrl = TextEditingController(text: _wishNote);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Buyurtma uchun istaklar"),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            hintText: "Masalan: Konditsioner, yukxona bo'sh bo'lsin...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBekGreen, foregroundColor: Colors.white),
            onPressed: () {
              setState(() => _wishNote = noteCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text("Saqlash"),
          ),
        ],
      ),
    );
  }

  void _submitOrder() {
    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Iltimos, xaritadan boradigan manzilingizni bosing yoki yozing!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final int finalPrice = _getTariffPrice(_selectedTariff);
    final newOrder = OrderModel(
      id: "ORD-${Random().nextInt(9000) + 1000}",
      clientPhone: _phoneController.text.trim(),
      fromAddress: _fromController.text.trim(),
      toAddress: _toController.text.trim().isEmpty ? "Xaritadan tanlangan nuqta" : _toController.text.trim(),
      fromPoint: _currentLocation,
      toPoint: _destinationLocation!,
      tariff: _selectedTariff,
      distanceKm: _distanceKm,
      price: finalPrice,
      createdAt: DateTime.now(),
    );

    appState.createOrder(newOrder);
    setState(() => _activeOrder = newOrder);
  }

  List<Marker> _buildNearbyTaxiMarkers() {
    final List<Offset> offsets = [
      const Offset(0.004, 0.003),
      const Offset(-0.003, 0.005),
      const Offset(0.005, -0.004),
      const Offset(-0.004, -0.003),
    ];
    return offsets
        .map(
          (off) => Marker(
            point: LatLng(_currentLocation.latitude + off.dx, _currentLocation.longitude + off.dy),
            width: 34,
            height: 34,
            child: Container(
              decoration: BoxDecoration(
                color: kTaxiYellow,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Icon(Icons.local_taxi, size: 18, color: Colors.black),
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final int pendingCount = appState.orders.where((o) => o.status == 'Kutilmoqda').length;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 14.8,
            onTap: (tapPosition, point) {
              if (_activeOrder == null ||
                  _activeOrder!.status == 'Yakunlandi' ||
                  _activeOrder!.status == 'Bekor qilindi') {
                setState(() {
                  _destinationLocation = point;
                  _toController.text =
                      "Manzil (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})";
                });
                _recalculateDistance();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://core-renderer-tiles.maps.yandex.net/tiles?l=map&x={x}&y={y}&z={z}&scale=2&lang=ru_RU&apikey=$yandexApiKey',
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
                ..._buildNearbyTaxiMarkers(),
                Marker(
                  point: _currentLocation,
                  width: 64,
                  height: 64,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: kBekGreen, width: 4),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        ),
                        child: Center(
                          child: Text(
                            "$_etaMinutes\nmin",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              height: 1.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Container(width: 3, height: 10, color: kBekGreen),
                    ],
                  ),
                ),
                if (_destinationLocation != null)
                  Marker(
                    point: _destinationLocation!,
                    width: 48,
                    height: 48,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 44),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 14,
          child: GestureDetector(
            onTap: widget.onOpenDrawer,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.menu, color: kBekGreen, size: 26),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 14,
          child: Row(
            children: [
              if (pendingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBekGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => widget.onQuickRoleSwitch(1),
                    icon: const Icon(Icons.local_taxi, size: 16),
                    label: Text("Haydovchi ($pendingCount)"),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_giftcard, color: kBekGreen, size: 20),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Bonuslar", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          "${appState.clientBonus}",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: appState.useBonus,
                        activeColor: kBekGreen,
                        onChanged: (v) => setState(() => appState.useBonus = v),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Y", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 13)),
                          Text("andex Maps", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    FloatingActionButton.small(
                      heroTag: "gps_btn",
                      backgroundColor: Colors.white,
                      onPressed: _determinePosition,
                      child: const Icon(Icons.my_location, color: kBekGreen),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16)],
                ),
                child: _buildBottomPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    if (_activeOrder != null && _activeOrder!.status != 'Bekor qilindi') {
      final String st = _activeOrder!.status;

      if (st == 'Yakunlandi') {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: kBekGreen, size: 32),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Safar muvaffaqiyatli yakunlandi!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text("Xizmatimizdan foydalanganingiz uchun rahmat.", style: TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(backgroundColor: kDarkBg, child: Icon(Icons.person, color: kTaxiYellow)),
              title: Text("${_activeOrder!.driverName ?? 'Sardor Aliyev'} ⭐ 4.95", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_activeOrder!.driverCar ?? "Oq Chevrolet Cobalt • 01 A 777 AA"),
              trailing: CircleAvatar(
                backgroundColor: Colors.green.shade50,
                child: const Icon(Icons.phone, color: kBekGreen),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("To'lov summasi (${_activeOrder!.distanceKm} km):", style: const TextStyle(color: Colors.grey)),
                Text("${_activeOrder!.price} so'm", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTaxiYellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  setState(() {
                    _activeOrder = null;
                    _destinationLocation = null;
                    _toController.clear();
                    _distanceKm = 0.0;
                  });
                },
                icon: const Icon(Icons.add_location_alt),
                label: const Text("YANGI BUYURTMA BERISH", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      }

      String statusHeadline = "Yaqin atrofdagi haydovchi qidirilmoqda...";
      String statusSub = "Manzil: ${_activeOrder!.toAddress}";
      IconData statusIcon = Icons.radar;
      Color statusColor = Colors.orange;

      if (st == 'Qabul qilindi') {
        statusHeadline = "Haydovchi buyurtmani qabul qildi va yo'lga chiqdi!";
        statusSub = "Taxminan 3 daqiqada yetib keladi";
        statusIcon = Icons.local_taxi;
        statusColor = Colors.blue;
      } else if (st == 'Yetib keldi') {
        statusHeadline = "Haydovchi manzilga yetib keldi, sizni kutmoqda!";
        statusSub = _activeOrder!.driverCar ?? "";
        statusIcon = Icons.notifications_active;
        statusColor = Colors.deepOrange;
      } else if (st == 'Safarda') {
        statusHeadline = "Safar davom etmoqda — Oq yo'l!";
        statusSub = "Borish manzili: ${_activeOrder!.toAddress}";
        statusIcon = Icons.navigation;
        statusColor = kBekGreen;
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: statusColor.withOpacity(0.15),
                child: Icon(statusIcon, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusHeadline, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(statusSub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (st != 'Kutilmoqda') ...[
            const Divider(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(backgroundColor: kDarkBg, child: Icon(Icons.person, color: kTaxiYellow)),
              title: Text("${_activeOrder!.driverName ?? 'Sardor Aliyev'} ⭐ 4.95", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_activeOrder!.driverCar ?? ""),
              trailing: CircleAvatar(
                backgroundColor: Colors.green.shade50,
                child: const Icon(Icons.phone, color: kBekGreen),
              ),
            ),
          ],
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("To'lov summasi (${_activeOrder!.distanceKm} km):", style: const TextStyle(color: Colors.grey)),
              Text("${_activeOrder!.price} so'm", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 10),
          if (st != 'Safarda')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  appState.cancelOrder(_activeOrder!.id);
                  setState(() => _activeOrder = null);
                },
                icon: const Icon(Icons.close, size: 18),
                label: const Text("Buyurtmani bekor qilish"),
              ),
            ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 24,
              child: Text("A", style: TextStyle(color: kBekGreen, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            Expanded(
              child: TextField(
                controller: _fromController,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: "Qayerdan olamiz?",
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 10),
        InkWell(
          onTap: _openDestinationSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                const SizedBox(
                  width: 24,
                  child: Text("B", style: TextStyle(color: kBekGreen, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Expanded(
                  child: Text(
                    _toController.text.isEmpty ? "Qayerga ketyapsiz? (Xaritadan bosing)" : _toController.text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _toController.text.isEmpty ? FontWeight.normal : FontWeight.w600,
                      color: _toController.text.isEmpty ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
                const Icon(Icons.search, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _serviceTab = 'Taksi';
                _selectedTariff = 'Standart';
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: _serviceTab == 'Taksi' ? kBekGreen : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Такси",
                  style: TextStyle(
                    color: _serviceTab == 'Taksi' ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() {
                _serviceTab = 'Dostavka';
                _selectedTariff = 'Dostavka';
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: _serviceTab == 'Dostavka' ? kBekGreen : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Доставка",
                  style: TextStyle(
                    color: _serviceTab == 'Dostavka' ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (_distanceKm > 0)
              Text(
                "$_distanceKm km • ~$_etaMinutes daq",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kBekGreen),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTariffCard("Standart", "Стандарт", "8 daq", Icons.local_taxi, kTaxiYellow),
              const SizedBox(width: 10),
              _buildTariffCard("Komfort", "Комфорт", "10 daq", Icons.directions_car, Colors.blueGrey),
              const SizedBox(width: 10),
              _buildTariffCard("Dostavka", "Доставка", "12 daq", Icons.local_shipping, Colors.orange),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: InkWell(
            onTap: _openWishesDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune, color: kBekGreen, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _wishNote.isEmpty ? "Istaklar" : "Istak: $_wishNote",
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBekGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              elevation: 2,
            ),
            onPressed: _submitOrder,
            child: Text(
              _destinationLocation == null
                  ? "Buyurtma berish"
                  : "Buyurtma berish • ${_getTariffPrice(_selectedTariff)} so'm",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTariffCard(String keyName, String label, String timeText, IconData carIcon, Color iconColor) {
    final bool isSelected = _selectedTariff == keyName;
    final int price = _getTariffPrice(keyName);

    return GestureDetector(
      onTap: () => setState(() => _selectedTariff = keyName),
      child: Container(
        width: 125,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? kBekGreen : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(timeText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Icon(carIcon, color: iconColor, size: 24),
              ],
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(
              _destinationLocation == null ? "min $price сум" : "$price сум",
              style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 2. HAYDOVCHI TERMINALI ====================
class DriverView extends StatefulWidget {
  const DriverView({super.key});

  @override
  State<DriverView> createState() => _DriverViewState();
}

class _DriverViewState extends State<DriverView> {
  int _driverIndex = 0;

  DriverModel get currentDriver => appState.drivers[_driverIndex];

  @override
  Widget build(BuildContext context) {
    final pendingOrders = appState.orders.where((o) => o.status == 'Kutilmoqda').toList();
    final activeOrders = appState.orders
        .where((o) =>
            (o.status == 'Qabul qilindi' || o.status == 'Yetib keldi' || o.status == 'Safarda') &&
            o.driverName == currentDriver.name)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _driverIndex,
                isExpanded: true,
                items: List.generate(
                  appState.drivers.length,
                  (index) {
                    final d = appState.drivers[index];
                    return DropdownMenuItem(
                      value: index,
                      child: Text(
                        "Profil: ${d.name} (${d.carModel} • ${d.carNumber})",
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    );
                  },
                ),
                onChanged: (val) {
                  if (val != null) setState(() => _driverIndex = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kDarkBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currentDriver.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text("${currentDriver.carModel} • ${currentDriver.carNumber}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(
                      "Balans: ${currentDriver.balance} so'm",
                      style: const TextStyle(color: kTaxiYellow, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Switch(
                      value: currentDriver.isOnline,
                      activeColor: kBekGreen,
                      onChanged: (v) => setState(() => currentDriver.isOnline = v),
                    ),
                    Text(
                      currentDriver.isOnline ? "ONLAYN (Liniyada)" : "OFLAYN",
                      style: TextStyle(
                        color: currentDriver.isOnline ? Colors.greenAccent : Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (activeOrders.isNotEmpty) ...[
            const Text("Faol buyurtmangiz:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...activeOrders.map((ord) => _buildActiveOrderCard(ord)),
            const SizedBox(height: 12),
          ],
          const Text("Yangi tushgan buyurtmalar:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Expanded(
            child: pendingOrders.isEmpty
                ? Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text("Hozircha yangi buyurtmalar yo'q...", style: TextStyle(color: Colors.grey)),
                  )
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
                                  Chip(
                                    label: Text(ord.tariff.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    backgroundColor: const Color(0xFFFFFBEB),
                                  ),
                                  Text("${ord.price} so'm", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kBekGreen)),
                                ],
                              ),
                              Text("🟢 Qayerdan: ${ord.fromAddress}"),
                              const SizedBox(height: 4),
                              Text("🔴 Qayerga: ${ord.toAddress}"),
                              const SizedBox(height: 4),
                              Text("📞 Tel: ${ord.clientPhone} • ${ord.distanceKm} km", style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kTaxiYellow,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    appState.updateOrderStatus(ord.id, 'Qabul qilindi', currentDriver);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Buyurtma qabul qilindi! Mijozga xabar yuborildi."),
                                        backgroundColor: kBekGreen,
                                      ),
                                    );
                                  },
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
      ),
    );
  }

  Widget _buildActiveOrderCard(OrderModel ord) {
    String btnText = "MANZILGA YETIB KELDIM";
    Color btnColor = Colors.orange;
    String nextStatus = 'Yetib keldi';

    if (ord.status == 'Yetib keldi') {
      btnText = "▶ SAFARNI BOSHLASH";
      btnColor = Colors.blue;
      nextStatus = 'Safarda';
    } else if (ord.status == 'Safarda') {
      btnText = "✓ SAFARNI YAKUNLASH";
      btnColor = kBekGreen;
      nextStatus = 'Yakunlandi';
    }

    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kBekGreen, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(label: Text(ord.tariff.toUpperCase())),
                Text("${ord.price} so'm", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kBekGreen)),
              ],
            ),
            Text("Mijoz tel: ${ord.clientPhone}", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("Qayerdan: ${ord.fromAddress}"),
            Text("Qayerga: ${ord.toAddress}"),
            Text("Masofa: ${ord.distanceKm} km"),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  appState.updateOrderStatus(ord.id, nextStatus, currentDriver);
                  if (nextStatus == 'Yakunlandi') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Safar yakunlandi! Mijoz ekrani ham avtomatik yangilandi."),
                        backgroundColor: kBekGreen,
                      ),
                    );
                  }
                },
                child: Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 3. OPERATOR PANELI ====================
class OperatorView extends StatefulWidget {
  const OperatorView({super.key});

  @override
  State<OperatorView> createState() => _OperatorViewState();
}

class _OperatorViewState extends State<OperatorView> {
  final TextEditingController _phoneCtrl = TextEditingController(text: "+998 91 972 88 47");
  final TextEditingController _fromCtrl = TextEditingController(text: "Markaziy bozor");
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _kmCtrl = TextEditingController(text: "3.5");

  void _sendManualOrder() {
    if (_fromCtrl.text.trim().isEmpty || _toCtrl.text.trim().isEmpty) return;
    final double km = double.tryParse(_kmCtrl.text) ?? 3.5;
    final int price = ((appState.stdBase + km * appState.stdPerKm) / 500).round() * 500;

    final ord = OrderModel(
      id: "OP-${Random().nextInt(9000) + 1000}",
      clientPhone: _phoneCtrl.text.trim(),
      fromAddress: _fromCtrl.text.trim(),
      toAddress: _toCtrl.text.trim(),
      fromPoint: wgs84ToYandex(37.8267, 67.5975),
      toPoint: wgs84ToYandex(37.8367, 67.6075),
      tariff: 'Standart',
      distanceKm: km,
      price: price,
      createdAt: DateTime.now(),
    );

    appState.createOrder(ord);
    _toCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Buyurtma haydovchilarga yuborildi!"), backgroundColor: kBekGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14.0),
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
                  const Text("Qo'lda buyurtma yaratish (Qo'ng'iroq orqali)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: "Mijoz telefoni", isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _fromCtrl,
                    decoration: const InputDecoration(labelText: "Qayerdan olish manzili", isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _toCtrl,
                          decoration: const InputDecoration(labelText: "Qayerga borish manzili", isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _kmCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Masofa (km)", isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: kTaxiYellow, foregroundColor: Colors.black),
                      onPressed: _sendManualOrder,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text("HAYDOVCHILARGA YUBORISH", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text("Barcha buyurtmalar monitoringi (${appState.orders.length}):", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: appState.orders.length,
              itemBuilder: (ctx, i) {
                final o = appState.orders[i];
                return Card(
                  child: ListTile(
                    title: Text("${o.fromAddress} ➔ ${o.toAddress}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      "Tel: ${o.clientPhone} • Narx: ${o.price} so'm\nHolat: ${o.status} • Haydovchi: ${o.driverName ?? '-'}",
                    ),
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

// ==================== 4. SUPER-ADMIN PANELI ====================
class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  late TextEditingController _sBaseCtrl;
  late TextEditingController _sKmCtrl;
  late TextEditingController _cBaseCtrl;
  late TextEditingController _cKmCtrl;
  late TextEditingController _dBaseCtrl;
  late TextEditingController _dKmCtrl;
  late TextEditingController _commCtrl;

  @override
  void initState() {
    super.initState();
    _sBaseCtrl = TextEditingController(text: appState.stdBase.toString());
    _sKmCtrl = TextEditingController(text: appState.stdPerKm.toString());
    _cBaseCtrl = TextEditingController(text: appState.comfBase.toString());
    _cKmCtrl = TextEditingController(text: appState.comfPerKm.toString());
    _dBaseCtrl = TextEditingController(text: appState.delivBase.toString());
    _dKmCtrl = TextEditingController(text: appState.delivPerKm.toString());
    _commCtrl = TextEditingController(text: appState.commissionPercent.toString());
  }

  void _saveAll() {
    appState.saveTariffs(
      sB: int.tryParse(_sBaseCtrl.text) ?? 4000,
      sK: int.tryParse(_sKmCtrl.text) ?? 2000,
      cB: int.tryParse(_cBaseCtrl.text) ?? 5000,
      cK: int.tryParse(_cKmCtrl.text) ?? 3000,
      dB: int.tryParse(_dBaseCtrl.text) ?? 6000,
      dK: int.tryParse(_dKmCtrl.text) ?? 2500,
      comm: double.tryParse(_commCtrl.text) ?? 10.0,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Barcha tariflar saqlandi!"), backgroundColor: kBekGreen),
    );
  }

  void _showAddDriverDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController carCtrl = TextEditingController();
    final TextEditingController numCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yangi haydovchi qo'shish"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "F.I.Sh")),
            TextField(controller: carCtrl, decoration: const InputDecoration(labelText: "Mashina rusumi")),
            TextField(controller: numCtrl, decoration: const InputDecoration(labelText: "Davlat raqami")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBekGreen, foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                appState.addNewDriver(nameCtrl.text.trim(), carCtrl.text.trim(), numCtrl.text.trim());
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
      padding: const EdgeInsets.all(14.0),
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
                  const Text("⚙ Tariflar va komissiya sozlamalari", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  _buildTariffRow("Standart", _sBaseCtrl, _sKmCtrl),
                  const SizedBox(height: 8),
                  _buildTariffRow("Komfort", _cBaseCtrl, _cKmCtrl),
                  const SizedBox(height: 8),
                  _buildTariffRow("Dostavka", _dBaseCtrl, _dKmCtrl),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _commCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Haydovchi komissiyasi (%)",
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kTaxiYellow, foregroundColor: Colors.black),
                      onPressed: _saveAll,
                      child: const Text("TARIFLARNI SAQLASH", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Haydovchilar bazasi (${appState.drivers.length}):", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kDarkBg, foregroundColor: kTaxiYellow),
                onPressed: _showAddDriverDialog,
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text("Haydovchi qo'shish"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...appState.drivers.map(
            (d) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: const Icon(Icons.directions_car, color: kBekGreen),
                ),
                title: Text("${d.name} (${d.carNumber})", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "${d.carModel} • ${d.tariffType} • Safarlar: ${d.trips}\nBalans: ${d.balance} so'm",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.add_card, color: Colors.blue),
                  onPressed: () => appState.addDriverBalance(d.id, 50000),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTariffRow(String title, TextEditingController bCtrl, TextEditingController kCtrl) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
          child: TextField(
            controller: bCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Boshlang'ich", isDense: true, border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: kCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "1 km narxi", isDense: true, border: OutlineInputBorder()),
          ),
        ),
      ],
    );
  }
}
// === KODNING OXIRI ===
