import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElegantTaxiApp());
}

// ============================================================================
// MODELLAR VA TIZIM HOLATLARI
// ============================================================================

enum AppRole { customer, driver, operatorRole, superAdmin }

enum TariffType { ekonom, komfort, dostavka }

enum OrderStatus {
  searching, // Haydovchi qidirilmoqda
  accepted,  // Haydovchi qabul qildi (yo'lda)
  arrived,   // Haydovchi yetib keldi
  inProgress,// Safar boshlandi
  completed, // Safar yakunlandi
  cancelled  // Bekor qilindi
}

class DriverModel {
  final String id;
  String name;
  String carModel;
  String carColor;
  String plateNumber;
  String phone;
  TariffType category;
  double balance;
  double rating;
  bool isOnline;
  LatLng location;
  int completedTrips;

  DriverModel({
    required this.id,
    required this.name,
    required this.carModel,
    required this.carColor,
    required this.plateNumber,
    required this.phone,
    this.category = TariffType.ekonom,
    required this.balance,
    this.rating = 4.9,
    this.isOnline = true,
    required this.location,
    this.completedTrips = 0,
  });
}

class OrderModel {
  final String id;
  final String customerPhone;
  final LatLng pickupLocation;
  final LatLng destinationLocation;
  final String pickupAddress;
  final String destinationAddress;
  final TariffType tariff;
  final double distanceKm;
  final int durationMin;
  final int priceSom;
  final DateTime createdAt;
  OrderStatus status;
  DriverModel? assignedDriver;

  OrderModel({
    required this.id,
    required this.customerPhone,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.tariff,
    required this.distanceKm,
    required this.durationMin,
    required this.priceSom,
    required this.createdAt,
    this.status = OrderStatus.searching,
    this.assignedDriver,
  });
}

// ============================================================================
// MARKAZIY BOSHQARUVCHI (REAL-TIME STATE MANAGEMENT)
// ============================================================================

class TaxiController extends ChangeNotifier {
  AppRole currentRole = AppRole.customer;
  bool isAdminAuthenticated = false;
  String _adminPassword = '9728847'; // Ekranda hech qachon ko'rsatilmaydi!

  // Tarif sozlamalari
  int basePriceEkonom = 4000;
  int perKmEkonom = 2000;
  int basePriceKomfort = 7000;
  int perKmKomfort = 3000;
  int basePriceDostavka = 6000;
  int perKmDostavka = 2500;
  double commissionPercent = 10.0; // Haydovchidan olinadigan komissiya (%)

  // Boshlang'ich koordinata
  LatLng currentGpsLocation = const LatLng(55.8045, 37.7082);
  String currentGpsAddress = 'Joriy joylashuv (Bogorodskoye, 12)';

  final List<DriverModel> drivers = [
    DriverModel(
      id: 'd1',
      name: 'Sardor Aliyev',
      carModel: 'Chevrolet Cobalt',
      carColor: 'Oq',
      plateNumber: '01 A 777 AA',
      phone: '+998 90 123 45 67',
      category: TariffType.ekonom,
      balance: 85000,
      rating: 4.95,
      isOnline: true,
      location: const LatLng(55.8065, 37.7120),
      completedTrips: 142,
    ),
    DriverModel(
      id: 'd2',
      name: 'Jasur Karimov',
      carModel: 'Chevrolet Gentra',
      carColor: 'Qora',
      plateNumber: '01 B 555 BB',
      phone: '+998 93 555 44 33',
      category: TariffType.komfort,
      balance: 120000,
      rating: 4.88,
      isOnline: true,
      location: const LatLng(55.8010, 37.7020),
      completedTrips: 98,
    ),
    DriverModel(
      id: 'd3',
      name: 'Ulug‘bek Rustamov',
      carModel: 'BYD Chazor',
      carColor: 'Kulrang',
      plateNumber: '01 Z 888 ZZ',
      phone: '+998 97 777 00 11',
      category: TariffType.komfort,
      balance: 64000,
      rating: 5.0,
      isOnline: true,
      location: const LatLng(55.7995, 37.7210),
      completedTrips: 215,
    ),
    DriverModel(
      id: 'd4',
      name: 'Bobur Toshmatov',
      carModel: 'Damas Labo',
      carColor: 'Oq',
      plateNumber: '01 D 222 DD',
      phone: '+998 99 888 11 22',
      category: TariffType.dostavka,
      balance: 45000,
      rating: 4.82,
      isOnline: true,
      location: const LatLng(55.8080, 37.6990),
      completedTrips: 76,
    ),
  ];

  String selectedDriverId = 'd1';
  final List<OrderModel> orders = [];
  OrderModel? activeCustomerOrder;

  DriverModel get currentDriver =>
      drivers.firstWhere((d) => d.id == selectedDriverId, orElse: () => drivers.first);

  List<OrderModel> get newOrders =>
      orders.where((o) => o.status == OrderStatus.searching).toList();

  OrderModel? get activeDriverOrder {
    try {
      return orders.firstWhere(
        (o) =>
            o.assignedDriver?.id == currentDriver.id &&
            (o.status == OrderStatus.accepted ||
                o.status == OrderStatus.arrived ||
                o.status == OrderStatus.inProgress),
      );
    } catch (_) {
      return null;
    }
  }

  void switchRole(AppRole role) {
    currentRole = role;
    notifyListeners();
  }

  bool verifyAdminPassword(String input) {
    if (input.trim() == _adminPassword) {
      isAdminAuthenticated = true;
      currentRole = AppRole.superAdmin;
      notifyListeners();
      return true;
    }
    return false;
  }

  void updateAdminPassword(String newPass) {
    if (newPass.trim().length >= 4) {
      _adminPassword = newPass.trim();
      notifyListeners();
    }
  }

  void selectActiveDriver(String id) {
    selectedDriverId = id;
    notifyListeners();
  }

  void toggleDriverOnline(String id, bool value) {
    final index = drivers.indexWhere((d) => d.id == id);
    if (index != -1) {
      drivers[index].isOnline = value;
      notifyListeners();
    }
  }

  // Tarif bo'yicha narxni darhol hisoblash
  int calculatePrice(TariffType tariff, double distanceKm) {
    int basePrice;
    int perKm;
    switch (tariff) {
      case TariffType.ekonom:
        basePrice = basePriceEkonom;
        perKm = perKmEkonom;
        break;
      case TariffType.komfort:
        basePrice = basePriceKomfort;
        perKm = perKmKomfort;
        break;
      case TariffType.dostavka:
        basePrice = basePriceDostavka;
        perKm = perKmDostavka;
        break;
    }
    final raw = basePrice + (distanceKm * perKm);
    // 500 so'mga yaxlitlash
    return ((raw / 500).round() * 500).clamp(basePrice, 1000000);
  }

  // Buyurtma yaratish (Mijoz yoki Operator tomonidan)
  OrderModel createOrder({
    required String phone,
    required LatLng pickupLoc,
    required LatLng destLoc,
    required String pickupAddr,
    required String destAddr,
    required TariffType tariff,
    required double distanceKm,
    required int durationMin,
  }) {
    final price = calculatePrice(tariff, distanceKm);
    final order = OrderModel(
      id: 'ORD-${1000 + orders.length + 1}',
      customerPhone: phone,
      pickupLocation: pickupLoc,
      destinationLocation: destLoc,
      pickupAddress: pickupAddr,
      destinationAddress: destAddr,
      tariff: tariff,
      distanceKm: distanceKm,
      durationMin: durationMin,
      priceSom: price,
      createdAt: DateTime.now(),
      status: OrderStatus.searching,
    );
    orders.insert(0, order);
    activeCustomerOrder = order;
    notifyListeners();
    return order;
  }

  // Buyurtmani bekor qilish
  void cancelOrder(String orderId) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      orders[idx].status = OrderStatus.cancelled;
      if (activeCustomerOrder?.id == orderId) {
        activeCustomerOrder = null;
      }
      notifyListeners();
    }
  }

  // Mijoz oynasini yangi buyurtma uchun tozalash
  void clearCompletedCustomerOrder() {
    activeCustomerOrder = null;
    notifyListeners();
  }

  // Haydovchi buyurtmani qabul qilishi
  String? acceptOrder(String orderId, {DriverModel? specificDriver}) {
    final driver = specificDriver ?? currentDriver;
    if (!driver.isOnline) {
      return 'Buyurtma olish uchun avval "Onlayn" rejimiga o‘ting!';
    }
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return 'Buyurtma topilmadi';

    final order = orders[idx];
    final commission = (order.priceSom * (commissionPercent / 100)).round();
    if (driver.balance < commission) {
      return 'Balansda yetarli mablag‘ yo‘q! Komissiya: $commission so‘m';
    }

    order.assignedDriver = driver;
    order.status = OrderStatus.accepted;
    notifyListeners();
    return null;
  }

  // Haydovchi mijoz oldiga yetib keldi
  void markDriverArrived(String orderId) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      orders[idx].status = OrderStatus.arrived;
      if (orders[idx].assignedDriver != null) {
        orders[idx].assignedDriver!.location = orders[idx].pickupLocation;
      }
      notifyListeners();
    }
  }

  // Safarni boshlash
  void startTrip(String orderId) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      orders[idx].status = OrderStatus.inProgress;
      notifyListeners();
    }
  }

  // Safarni yakunlash
  void completeTrip(String orderId) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final order = orders[idx];
      order.status = OrderStatus.completed;
      final driver = order.assignedDriver;
      if (driver != null) {
        final commission = (order.priceSom * (commissionPercent / 100)).round();
        driver.balance -= commission;
        driver.completedTrips += 1;
        driver.location = order.destinationLocation;
      }
      notifyListeners();
    }
  }

  // Super-Admin: Tariflarni yangilash
  void updateTariffs({
    required int baseEkonom,
    required int kmEkonom,
    required int baseKomfort,
    required int kmKomfort,
    required int baseDostavka,
    required int kmDostavka,
    required double commission,
  }) {
    basePriceEkonom = baseEkonom;
    perKmEkonom = kmEkonom;
    basePriceKomfort = baseKomfort;
    perKmKomfort = kmKomfort;
    basePriceDostavka = baseDostavka;
    perKmDostavka = kmDostavka;
    commissionPercent = commission;
    notifyListeners();
  }

  // Super-Admin: Haydovchi balansini to'ldirish
  void topUpDriverBalance(String driverId, double amount) {
    final idx = drivers.indexWhere((d) => d.id == driverId);
    if (idx != -1) {
      drivers[idx].balance += amount;
      notifyListeners();
    }
  }

  // Super-Admin: Yangi haydovchi qo'shish
  void addDriver({
    required String name,
    required String carModel,
    required String carColor,
    required String plateNumber,
    required String phone,
    required TariffType category,
    required double initialBalance,
  }) {
    final randomOffset = (Random().nextDouble() - 0.5) * 0.015;
    drivers.add(
      DriverModel(
        id: 'd${drivers.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        carModel: carModel,
        carColor: carColor,
        plateNumber: plateNumber,
        phone: phone,
        category: category,
        balance: initialBalance,
        location: LatLng(
          currentGpsLocation.latitude + randomOffset,
          currentGpsLocation.longitude + randomOffset,
        ),
      ),
    );
    notifyListeners();
  }
}

// ============================================================================
// GEOCODING VA MARSHRUT XIZMATI (NOMINATIM + OSRM API)
// ============================================================================

class GeoService {
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  // Koordinatani haqiqiy ko'cha va manzil nomiga o'girish (Reverse Geocoding)
  static Future<String> getAddressFromLatLng(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2'
        '&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );
      final req = await _client.getUrl(url);
      req.headers.set('User-Agent', 'ElegantTaxiProApp/2.0');
      req.headers.set('Accept-Language', 'uz,ru,en');
      final res = await req.close().timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;

        if (addr != null) {
          final road = addr['road'] ??
              addr['pedestrian'] ??
              addr['neighbourhood'] ??
              addr['suburb'] ??
              addr['residential'];
          final house = addr['house_number'];
          final poi = data['name'];
          final district = addr['suburb'] ?? addr['city_district'] ?? addr['town'] ?? '';

          final parts = <String>[];
          if (poi != null && poi.toString().isNotEmpty && poi != road) {
            parts.add(poi.toString());
          }
          if (road != null && road.toString().isNotEmpty) {
            parts.add(house != null ? '$road, $house' : road.toString());
          }
          if (parts.isEmpty && district.toString().isNotEmpty) {
            parts.add(district.toString());
          }
          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
        if (data['display_name'] != null) {
          final segments = data['display_name'].toString().split(',');
          return segments.take(2).map((e) => e.trim()).join(', ');
        }
      }
    } catch (_) {
      // Internet sust bo'lganda zaxira formatlash
    }
    return 'Belgilangan nuqta (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
  }

  // Matn orqali manzil qidirish (Nominatim Search)
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final encoded = Uri.encodeComponent(query.trim());
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encoded&format=jsonv2&limit=6&addressdetails=1',
      );
      final req = await _client.getUrl(url);
      req.headers.set('User-Agent', 'ElegantTaxiProApp/2.0');
      req.headers.set('Accept-Language', 'uz,ru,en');
      final res = await req.close().timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final list = jsonDecode(body) as List<dynamic>;
        return list.map((item) {
          final display = item['display_name'].toString().split(',').take(3).join(', ');
          return {
            'title': display,
            'latLng': LatLng(
              double.parse(item['lat'].toString()),
              double.parse(item['lon'].toString()),
            ),
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  // Haqiqiy avtomobil yo'li bo'ylab marshrut chizish va masofani olish (OSRM)
  static Future<Map<String, dynamic>> getRoadRoute(LatLng start, LatLng end) async {
    final straightDist = calculateStraightDistanceKm(start, end);
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson',
      );
      final req = await _client.getUrl(url);
      req.headers.set('User-Agent', 'ElegantTaxiProApp/2.0');
      final res = await req.close().timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSeconds = (route['duration'] as num).toDouble();
          final coords = (route['geometry']['coordinates'] as List<dynamic>)
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();

          return {
            'points': coords,
            'distanceKm': double.parse((distanceMeters / 1000).toStringAsFixed(1)),
            'durationMin': max(2, (durationSeconds / 60).round()),
          };
        }
      }
    } catch (_) {}

    // Offline yoki javob kechiksa zaxira hisob
    final roadDist = double.parse((straightDist * 1.25).toStringAsFixed(1));
    return {
      'points': <LatLng>[start, end],
      'distanceKm': roadDist,
      'durationMin': max(3, (roadDist * 2.2).round()),
    };
  }

  static double calculateStraightDistanceKm(LatLng a, LatLng b) {
    const distance = Distance();
    final km = distance.as(LengthUnit.Kilometer, a, b);
    return double.parse(km.toStringAsFixed(1));
  }
}

// ============================================================================
// ASOSIY ILOVA VA YON MENYU (DRAWER)
// ============================================================================

class ElegantTaxiApp extends StatefulWidget {
  const ElegantTaxiApp({super.key});

  @override
  State<ElegantTaxiApp> createState() => _ElegantTaxiAppState();
}

class _ElegantTaxiAppState extends State<ElegantTaxiApp> {
  final TaxiController controller = TaxiController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elegant Taxi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFFC107),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF14171F),
          foregroundColor: Color(0xFFFFC107),
          elevation: 0,
        ),
      ),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return MainShellScreen(controller: controller);
        },
      ),
    );
  }
}

class MainShellScreen extends StatelessWidget {
  final TaxiController controller;
  const MainShellScreen({super.key, required this.controller});

  void _openAdminLoginDialog(BuildContext context) {
    if (controller.isAdminAuthenticated) {
      controller.switchRole(AppRole.superAdmin);
      return;
    }

    final passCtrl = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFFFA000)),
                  SizedBox(width: 10),
                  Text('Super-Admin Himoyasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Maxfiy parolni kiriting',
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: errorText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Bekor qilish'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (controller.verifyAdminPassword(passCtrl.text)) {
                      Navigator.pop(ctx);
                    } else {
                      setDialogState(() {
                        errorText = 'Parol noto‘g‘ri!';
                      });
                    }
                  },
                  child: const Text('KIRISH', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String title;
    switch (controller.currentRole) {
      case AppRole.customer:
        title = 'ELEGANT TAXI';
        break;
      case AppRole.driver:
        title = 'HAYDOVCHI TERMINALI';
        break;
      case AppRole.operatorRole:
        title = 'OPERATOR MARKAZI';
        break;
      case AppRole.superAdmin:
        title = 'SUPER-ADMIN BOSHQARUVI';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_taxi_rounded, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (controller.currentRole != AppRole.customer)
            TextButton.icon(
              onPressed: () => controller.switchRole(AppRole.customer),
              icon: const Icon(Icons.person, color: Colors.white, size: 18),
              label: const Text('Mijoz', style: TextStyle(color: Colors.white)),
            ),
          if (controller.currentRole == AppRole.customer && controller.newOrders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                backgroundColor: Colors.green.shade700,
                avatar: const Icon(Icons.notifications_active, color: Colors.white, size: 16),
                label: Text(
                  'Haydovchi (${controller.newOrders.length})',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => controller.switchRole(AppRole.driver),
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF14171F), Color(0xFF252A38)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFC107),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_taxi, size: 32, color: Colors.black),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'ELEGANT TAXI PRO',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Yagona tezkor dispetcherlik tizimi',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ),
            ListTile(
              selected: controller.currentRole == AppRole.customer,
              leading: const Icon(Icons.map_rounded, color: Colors.blue),
              title: const Text('Mijoz (Taksi chaqirish)', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                controller.switchRole(AppRole.customer);
              },
            ),
            ListTile(
              selected: controller.currentRole == AppRole.driver,
              leading: const Icon(Icons.drive_eta_rounded, color: Colors.green),
              title: const Text('Haydovchi rejimi', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${controller.newOrders.length} ta yangi buyurtma'),
              trailing: controller.newOrders.isNotEmpty
                  ? CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.red,
                      child: Text(
                        '${controller.newOrders.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                controller.switchRole(AppRole.driver);
              },
            ),
            ListTile(
              selected: controller.currentRole == AppRole.operatorRole,
              leading: const Icon(Icons.support_agent_rounded, color: Colors.orange),
              title: const Text('Operator paneli', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Qo‘lda buyurtma va nazorat'),
              onTap: () {
                Navigator.pop(context);
                controller.switchRole(AppRole.operatorRole);
              },
            ),
            const Divider(),
            ListTile(
              selected: controller.currentRole == AppRole.superAdmin,
              leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.redAccent),
              // Parol bu yerda umuman ko'rinmaydi!
              title: const Text('Super-Admin', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Tariflar, haydovchilar va balans'),
              onTap: () {
                Navigator.pop(context);
                _openAdminLoginDialog(context);
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: controller.currentRole.index,
        children: [
          CustomerScreen(controller: controller),
          DriverScreen(controller: controller),
          OperatorScreen(controller: controller),
          SuperAdminScreen(controller: controller),
        ],
      ),
    );
  }
}

// ============================================================================
// 1. MIJOZ EKRANI (HAQIQIY MANZILLAR, MARSHRUT VA JONLI BUYURTMA HOLATI)
// ============================================================================

class CustomerScreen extends StatefulWidget {
  final TaxiController controller;
  const CustomerScreen({super.key, required this.controller});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _phoneController = TextEditingController(text: '+998 90 ');

  LatLng? _destinationPoint;
  String _destinationAddress = '';
  bool _isLoadingAddress = false;

  List<LatLng> _routePoints = [];
  double _distanceKm = 0.0;
  int _durationMin = 0;
  TariffType _selectedTariff = TariffType.ekonom;
  int _requestToken = 0;

  // Xaritadan joy bosilganda darhol masofani hisoblash va ko'cha nomini olish
  Future<void> _selectDestinationOnMap(LatLng point, {String? presetAddress}) async {
    final token = ++_requestToken;
    final pickup = widget.controller.currentGpsLocation;
    final instantDist = max(0.5, GeoService.calculateStraightDistanceKm(pickup, point) * 1.2);

    setState(() {
      _destinationPoint = point;
      _distanceKm = double.parse(instantDist.toStringAsFixed(1));
      _durationMin = max(3, (_distanceKm * 2.2).round());
      _routePoints = [pickup, point];
      _isLoadingAddress = presetAddress == null;
      _destinationAddress = presetAddress ?? 'Manzil aniqlanmoqda...';
    });

    // Parallel ravishda ko'cha nomi va avtomobil yo'li marshrutini olish
    final results = await Future.wait([
      presetAddress != null ? Future.value(presetAddress) : GeoService.getAddressFromLatLng(point),
      GeoService.getRoadRoute(pickup, point),
    ]);

    if (!mounted || token != _requestToken) return;

    final resolvedAddress = results[0] as String;
    final routeData = results[1] as Map<String, dynamic>;

    setState(() {
      _destinationAddress = resolvedAddress;
      _isLoadingAddress = false;
      _routePoints = routeData['points'] as List<LatLng>;
      _distanceKm = routeData['distanceKm'] as double;
      _durationMin = routeData['durationMin'] as int;
    });
  }

  // Qidiruv oynasi orqali manzil yozib topish
  void _openAddressSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        List<Map<String, dynamic>> searchResults = [];
        bool searching = false;
        Timer? debounce;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void runSearch(String text) {
              debounce?.cancel();
              if (text.trim().length < 2) {
                setModalState(() {
                  searchResults = [];
                  searching = false;
                });
                return;
              }
              setModalState(() => searching = true);
              debounce = Timer(const Duration(milliseconds: 350), () async {
                final res = await GeoService.searchAddress(text);
                if (ctx.mounted) {
                  setModalState(() {
                    searchResults = res;
                    searching = false;
                  });
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: runSearch,
                    decoration: InputDecoration(
                      hintText: 'Ko‘cha, bino yoki mo‘ljalni yozing...',
                      prefixIcon: const Icon(Icons.search, color: Colors.amber),
                      suffixIcon: searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (searchResults.isEmpty && !searching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Manzil nomini yozing yoki xaritadan istalgan joyga bosing',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = searchResults[i];
                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.redAccent),
                          title: Text(
                            item['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          onTap: () {
                            final pt = item['latLng'] as LatLng;
                            final title = item['title'] as String;
                            Navigator.pop(ctx);
                            _mapController.move(pt, 15);
                            _selectDestinationOnMap(pt, presetAddress: title);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _submitOrder() {
    if (_destinationPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Iltimos, xaritadan boradigan manzilingizni belgilang!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final cleanPhone = _phoneController.text.trim();
    if (cleanPhone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telefon raqamingizni to‘liq kiriting!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    widget.controller.createOrder(
      phone: cleanPhone,
      pickupLoc: widget.controller.currentGpsLocation,
      destLoc: _destinationPoint!,
      pickupAddr: widget.controller.currentGpsAddress,
      destAddr: _destinationAddress,
      tariff: _selectedTariff,
      distanceKm: _distanceKm,
      durationMin: _durationMin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeOrder = widget.controller.activeCustomerOrder;
    final currentPrice = widget.controller.calculatePrice(_selectedTariff, _distanceKm);

    return Stack(
      children: [
        // XARITA
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.controller.currentGpsLocation,
            initialZoom: 14.2,
            onTap: (tapPos, latlng) {
              if (activeOrder == null) {
                _selectDestinationOnMap(latlng);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.elegant.taxi.pro',
            ),
            if (_routePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5.0,
                    color: const Color(0xFF1976D2),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                // Mijoz GPS nuqtasi
                Marker(
                  point: widget.controller.currentGpsLocation,
                  width: 48,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.my_location_rounded, color: Colors.blue, size: 28),
                    ),
                  ),
                ),
                // Onlayn haydovchilar xaritada mashina belgisi bilan ko'rinadi
                ...widget.controller.drivers.where((d) => d.isOnline).map(
                      (driver) => Marker(
                        point: driver.location,
                        width: 44,
                        height: 44,
                        child: Tooltip(
                          message: '${driver.name} (${driver.carModel})',
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF14171F),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFFC107), width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.local_taxi, color: Color(0xFFFFC107), size: 22),
                          ),
                        ),
                      ),
                    ),
                // Tanlangan borish manzili (ustida manzil yozuvi bilan!)
                if (_destinationPoint != null)
                  Marker(
                    point: _destinationPoint!,
                    width: 220,
                    height: 75,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14171F),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: Text(
                            _destinationAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.location_on_rounded, color: Colors.red, size: 38),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),

        // GPS MARKAZLASHTIRISH TUGMASI
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'gps_btn',
            backgroundColor: const Color(0xFF14171F),
            foregroundColor: const Color(0xFFFFC107),
            onPressed: () {
              _mapController.move(widget.controller.currentGpsLocation, 15);
            },
            child: const Icon(Icons.gps_fixed_rounded),
          ),
        ),

        // PASTKI PANEL (BUYURTMA BERISH YOKI JONLI BUYURTMA HOLATI)
        Align(
          alignment: Alignment.bottomCenter,
          child: activeOrder == null
              ? _buildOrderCreationPanel(currentPrice)
              : _buildLiveOrderStatusPanel(activeOrder),
        ),
      ],
    );
  }

  Widget _buildOrderCreationPanel(int currentPrice) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Qayerdan
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.trip_origin_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.controller.currentGpsAddress,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Qayerga (Bosganda qidiruv ochiladi yoki xaritadan tanlanadi)
          InkWell(
            onTap: _openAddressSearchModal,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _destinationPoint != null ? Colors.amber.shade700 : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _destinationPoint == null
                          ? 'Qayerga? (Xaritadan bosing yoki qidiring)'
                          : _destinationAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: _destinationPoint == null ? FontWeight.w500 : FontWeight.bold,
                        color: _destinationPoint == null ? Colors.grey.shade600 : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (_isLoadingAddress)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.search_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Telefon raqami
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone_rounded, color: Colors.blue),
              hintText: '+998 90 123 45 67',
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tarif tanlash (Ekonom, Komfort, Dostavka)
          Row(
            children: [
              _buildTariffCard(TariffType.ekonom, 'Ekonom', Icons.local_taxi_rounded),
              const SizedBox(width: 8),
              _buildTariffCard(TariffType.komfort, 'Komfort', Icons.directions_car_filled_rounded),
              const SizedBox(width: 8),
              _buildTariffCard(TariffType.dostavka, 'Dostavka', Icons.inventory_2_rounded),
            ],
          ),
          const SizedBox(height: 14),

          // Masofa, vaqt va yakuniy narx
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.route_rounded, size: 18, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Masofa: ${_distanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                  if (_durationMin > 0) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.schedule_rounded, size: 17, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '~$_durationMin daq',
                      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
              Text(
                '$currentPrice so‘m',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF14171F)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Buyurtma berish tugmasi
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submitOrder,
              child: const Text(
                'BUYURTMA BERISH',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTariffCard(TariffType type, String label, IconData icon) {
    final isSelected = _selectedTariff == type;
    final price = widget.controller.calculatePrice(type, _distanceKm);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTariff = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF8E1) : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFFFC107) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: isSelected ? Colors.amber.shade900 : Colors.grey.shade600),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? Colors.black : Colors.grey.shade700,
                ),
              ),
              Text(
                '$price so‘m',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.amber.shade900 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MIJOZ UCHUN JONLI BUYURTMA OYNASI (HAYDOVCHI QABUL QILGANDA DARHOL O'ZGARADI!)
  Widget _buildLiveOrderStatusPanel(OrderModel order) {
    final driver = order.assignedDriver;

    IconData statusIcon;
    Color statusColor;
    String statusTitle;
    String statusSubtitle;

    switch (order.status) {
      case OrderStatus.searching:
        statusIcon = Icons.radar_rounded;
        statusColor = Colors.amber.shade800;
        statusTitle = 'Yaqin atrofdagi haydovchi qidirilmoqda...';
        statusSubtitle = 'Manzil: ${order.destinationAddress}';
        break;
      case OrderStatus.accepted:
        statusIcon = Icons.directions_car_rounded;
        statusColor = Colors.blue.shade700;
        statusTitle = 'Haydovchi buyurtmani qabul qildi va yo‘lga chiqdi!';
        statusSubtitle = 'Taxminan 3 daqiqada yetib keladi';
        break;
      case OrderStatus.arrived:
        statusIcon = Icons.notifications_active_rounded;
        statusColor = Colors.orange.shade800;
        statusTitle = 'Haydovchi manzilga yetib keldi, sizni kutmoqda!';
        statusSubtitle = '${driver?.carColor} ${driver?.carModel} (${driver?.plateNumber})';
        break;
      case OrderStatus.inProgress:
        statusIcon = Icons.navigation_rounded;
        statusColor = Colors.green.shade700;
        statusTitle = 'Safar davom etmoqda — Oq yo‘l!';
        statusSubtitle = 'Borish manzili: ${order.destinationAddress}';
        break;
      case OrderStatus.completed:
        statusIcon = Icons.verified_rounded;
        statusColor = Colors.teal.shade700;
        statusTitle = 'Safar muvaffaqiyatli yakunlandi!';
        statusSubtitle = 'Xizmatimizdan foydalanganingiz uchun rahmat.';
        break;
      case OrderStatus.cancelled:
        statusIcon = Icons.cancel_rounded;
        statusColor = Colors.red;
        statusTitle = 'Buyurtma bekor qilindi';
        statusSubtitle = '';
        break;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: statusColor.withOpacity(0.15),
                child: Icon(statusIcon, color: statusColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      statusSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Agar haydovchi biriktirilgan bo'lsa, haydovchi haqida to'liq ma'lumot
          if (driver != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF14171F),
                    child: Icon(Icons.person, color: Color(0xFFFFC107)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              driver.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 17),
                            Text(
                              driver.rating.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${driver.carColor} ${driver.carModel} • ${driver.plateNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Haydovchiga qo‘ng‘iroq: ${driver.phone}')),
                      );
                    },
                    icon: const Icon(Icons.phone, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To‘lov summasi (${order.distanceKm} km):',
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
              Text(
                '${order.priceSom} so‘m',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (order.status == OrderStatus.searching || order.status == OrderStatus.accepted)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => widget.controller.cancelOrder(order.id),
                icon: const Icon(Icons.close),
                label: const Text('Buyurtmani bekor qilish', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

          if (order.status == OrderStatus.completed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  setState(() {
                    _destinationPoint = null;
                    _destinationAddress = '';
                    _routePoints = [];
                    _distanceKm = 0.0;
                    _durationMin = 0;
                  });
                  widget.controller.clearCompletedCustomerOrder();
                },
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('YANGI BUYURTMA BERISH', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. HAYDOVCHI TERMINALI (KO'P HAYDOVCHILAR, TEZKOR QABUL VA BOSQICHLAR)
// ============================================================================

class DriverScreen extends StatelessWidget {
  final TaxiController controller;
  const DriverScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final driver = controller.currentDriver;
    final activeOrder = controller.activeDriverOrder;
    final incomingOrders = controller.newOrders;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Haydovchini almashtirish (Test va ko'p haydovchilar uchun qulay)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: driver.id,
              isExpanded: true,
              icon: const Icon(Icons.swap_horiz_rounded),
              items: controller.drivers.map((d) {
                return DropdownMenuItem(
                  value: d.id,
                  child: Text(
                    'Profil: ${d.name} (${d.carColor} ${d.carModel} • ${d.plateNumber})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) controller.selectActiveDriver(val);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Haydovchi asosiy kartochkasi
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF14171F),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${driver.carColor} ${driver.carModel} • ${driver.plateNumber}',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: driver.isOnline,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) => controller.toggleDriverOnline(driver.id, val),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Balans: ${driver.balance.toInt()} so‘m',
                    style: const TextStyle(color: Color(0xFFFFC107), fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: driver.isOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      driver.isOnline ? 'ONLAYN (Liniyada)' : 'OFLAYN',
                      style: TextStyle(
                        color: driver.isOnline ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // FAOL BUYURTMA BLOKI
        if (activeOrder != null) ...[
          const Text(
            'Faol buyurtmangiz:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(
                        activeOrder.tariff.name.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      backgroundColor: Colors.amber.shade100,
                    ),
                    Text(
                      '${activeOrder.priceSom} so‘m',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Mijoz tel: ${activeOrder.customerPhone}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Qayerdan: ${activeOrder.pickupAddress}'),
                const SizedBox(height: 4),
                Text(
                  'Qayerga: ${activeOrder.destinationAddress}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Masofa: ${activeOrder.distanceKm} km (~${activeOrder.durationMin} daq)',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Bosqichma-bosqich tugmalar (Mijoz ekranida darhol yangilanadi!)
                if (activeOrder.status == OrderStatus.accepted)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => controller.markDriverArrived(activeOrder.id),
                      icon: const Icon(Icons.location_on),
                      label: const Text('MANZILGA YETIB KELDIM', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),

                if (activeOrder.status == OrderStatus.arrived)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => controller.startTrip(activeOrder.id),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('SAFARNI BOSHLASH', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),

                if (activeOrder.status == OrderStatus.inProgress)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        controller.completeTrip(activeOrder.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Safar yakunlandi! Mijoz ekrani ham avtomatik yangilandi.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('SAFARNI YAKUNLASH', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // YANGI TUSHGAN ZAKAZLAR RO'YXATI
        const Text(
          'Yangi tushgan buyurtmalar:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        if (incomingOrders.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Text(
                'Hozircha yangi buyurtmalar yo‘q...',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
          )
        else
          ...incomingOrders.map((order) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.tariff.name.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      Text(
                        '${order.priceSom} so‘m',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.my_location, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Qayerdan: ${order.pickupAddress}')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Qayerga: ${order.destinationAddress}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Text('Tel: ${order.customerPhone} • ${order.distanceKm} km'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final err = controller.acceptOrder(order.id);
                        if (err != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err), backgroundColor: Colors.red),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Buyurtma qabul qilindi! Mijozga xabar yuborildi.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: const Text('QABUL QILISH', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ============================================================================
// 3. OPERATOR PANELI (QO'LDA BUYURTMA KIRITISH VA DISPETCHERLIK NAZORATI)
// ============================================================================

class OperatorScreen extends StatefulWidget {
  final TaxiController controller;
  const OperatorScreen({super.key, required this.controller});

  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  final _phoneCtrl = TextEditingController(text: '+998 ');
  final _pickupCtrl = TextEditingController(text: 'Markaziy bozor');
  final _destCtrl = TextEditingController();
  final _kmCtrl = TextEditingController(text: '3.5');
  TariffType _tariff = TariffType.ekonom;

  void _createManualOrder() {
    if (_destCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borish manzilini kiriting!'), backgroundColor: Colors.red),
      );
      return;
    }
    final km = double.tryParse(_kmCtrl.text) ?? 3.0;
    widget.controller.createOrder(
      phone: _phoneCtrl.text.trim(),
      pickupLoc: widget.controller.currentGpsLocation,
      destLoc: LatLng(
        widget.controller.currentGpsLocation.latitude + 0.01,
        widget.controller.currentGpsLocation.longitude + 0.01,
      ),
      pickupAddr: _pickupCtrl.text.trim(),
      destAddr: _destCtrl.text.trim(),
      tariff: _tariff,
      distanceKm: km,
      durationMin: max(3, (km * 2.2).round()),
    );
    _destCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yangi buyurtma tizimga qo‘shildi!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Qo‘lda tez buyurtma yaratish (Qo‘ng‘iroq orqali)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Mijoz telefoni', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pickupCtrl,
                decoration: const InputDecoration(labelText: 'Qayerdan olish manzili', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _destCtrl,
                      decoration: const InputDecoration(labelText: 'Qayerga borish manzili', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _kmCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Masofa (km)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _createManualOrder,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('HAYDOVCHILARGA YUBORISH', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Barcha buyurtmalar monitoringi (${widget.controller.orders.length}):',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        ...widget.controller.orders.map((o) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text('${o.pickupAddress} → ${o.destinationAddress}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Tel: ${o.customerPhone} • Narx: ${o.priceSom} so‘m\n'
                'Holat: ${o.status.name.toUpperCase()} '
                '${o.assignedDriver != null ? "• Haydovchi: ${o.assignedDriver!.name}" : ""}',
              ),
              isThreeLine: true,
              trailing: o.status == OrderStatus.searching
                  ? PopupMenuButton<DriverModel>(
                      tooltip: 'Haydovchi biriktirish',
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.blue),
                      onSelected: (driver) {
                        widget.controller.acceptOrder(o.id, specificDriver: driver);
                      },
                      itemBuilder: (_) => widget.controller.drivers
                          .where((d) => d.isOnline)
                          .map((d) => PopupMenuItem(value: d, child: Text('${d.name} (${d.plateNumber})')))
                          .toList(),
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

// ============================================================================
// 4. SUPER-ADMIN BOSHQARUVI (MAXFIY, BARCHA TARIFLAR VA HAYDOVCHILAR BAZASI)
// ============================================================================

class SuperAdminScreen extends StatefulWidget {
  final TaxiController controller;
  const SuperAdminScreen({super.key, required this.controller});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  late final TextEditingController _baseEkonomCtrl;
  late final TextEditingController _kmEkonomCtrl;
  late final TextEditingController _baseKomfortCtrl;
  late final TextEditingController _kmKomfortCtrl;
  late final TextEditingController _baseDostavkaCtrl;
  late final TextEditingController _kmDostavkaCtrl;
  late final TextEditingController _commCtrl;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _baseEkonomCtrl = TextEditingController(text: c.basePriceEkonom.toString());
    _kmEkonomCtrl = TextEditingController(text: c.perKmEkonom.toString());
    _baseKomfortCtrl = TextEditingController(text: c.basePriceKomfort.toString());
    _kmKomfortCtrl = TextEditingController(text: c.perKmKomfort.toString());
    _baseDostavkaCtrl = TextEditingController(text: c.basePriceDostavka.toString());
    _kmDostavkaCtrl = TextEditingController(text: c.perKmDostavka.toString());
    _commCtrl = TextEditingController(text: c.commissionPercent.toString());
  }

  void _showTopUpDialog(DriverModel driver) {
    final amountCtrl = TextEditingController(text: '50000');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${driver.name} balansini to‘ldirish'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Summa (so‘m)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
            onPressed: () {
              final val = double.tryParse(amountCtrl.text) ?? 0;
              if (val > 0) {
                widget.controller.topUpDriverBalance(driver.id, val);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${driver.name} hisobiga ${val.toInt()} so‘m qo‘shildi!'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('TO‘LDIRISH', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddDriverDialog() {
    final nameCtrl = TextEditingController();
    final carCtrl = TextEditingController(text: 'Chevrolet Cobalt');
    final colorCtrl = TextEditingController(text: 'Oq');
    final plateCtrl = TextEditingController(text: '01 M 999 MM');
    final phoneCtrl = TextEditingController(text: '+998 90 ');
    final balCtrl = TextEditingController(text: '50000');
    TariffType selectedCat = TariffType.ekonom;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Yangi haydovchi qo‘shish'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Ism-familiya')),
                const SizedBox(height: 8),
                TextField(controller: carCtrl, decoration: const InputDecoration(labelText: 'Avtomobil rusumi')),
                const SizedBox(height: 8),
                TextField(controller: colorCtrl, decoration: const InputDecoration(labelText: 'Rangi')),
                const SizedBox(height: 8),
                TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Davlat raqami')),
                const SizedBox(height: 8),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefon raqami')),
                const SizedBox(height: 8),
                DropdownButtonFormField<TariffType>(
                  value: selectedCat,
                  decoration: const InputDecoration(labelText: 'Tarif toifasi'),
                  items: TariffType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase())))
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedCat = v ?? TariffType.ekonom),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: balCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Boshlang‘ich balans (so‘m)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                widget.controller.addDriver(
                  name: nameCtrl.text.trim(),
                  carModel: carCtrl.text.trim(),
                  carColor: colorCtrl.text.trim(),
                  plateNumber: plateCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  category: selectedCat,
                  initialBalance: double.tryParse(balCtrl.text) ?? 50000,
                );
                Navigator.pop(ctx);
              },
              child: const Text('QO‘SHISH', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // TARIFLAR PANELI
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Tariflar va komissiya sozlamalari', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              _buildTariffRow('Ekonom', _baseEkonomCtrl, _kmEkonomCtrl),
              const SizedBox(height: 10),
              _buildTariffRow('Komfort', _baseKomfortCtrl, _kmKomfortCtrl),
              const SizedBox(height: 10),
              _buildTariffRow('Dostavka', _baseDostavkaCtrl, _kmDostavkaCtrl),
              const SizedBox(height: 10),
              TextField(
                controller: _commCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Haydovchi komissiyasi (%)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    widget.controller.updateTariffs(
                      baseEkonom: int.tryParse(_baseEkonomCtrl.text) ?? 4000,
                      kmEkonom: int.tryParse(_kmEkonomCtrl.text) ?? 2000,
                      baseKomfort: int.tryParse(_baseKomfortCtrl.text) ?? 7000,
                      kmKomfort: int.tryParse(_kmKomfortCtrl.text) ?? 3000,
                      baseDostavka: int.tryParse(_baseDostavkaCtrl.text) ?? 6000,
                      kmDostavka: int.tryParse(_kmDostavkaCtrl.text) ?? 2500,
                      commission: double.tryParse(_commCtrl.text) ?? 10.0,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tariflar muvaffaqiyatli saqlandi!'), backgroundColor: Colors.green),
                    );
                  },
                  child: const Text('TARIFLARNI SAQLASH', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // HAYDOVCHILAR RO'YXATI VA BALANS BOSHQARUVI
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Haydovchilar bazasi (${widget.controller.drivers.length}):',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14171F),
                foregroundColor: const Color(0xFFFFC107),
              ),
              onPressed: _showAddDriverDialog,
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Haydovchi qo‘shish'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...widget.controller.drivers.map((d) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: d.isOnline ? Colors.green.shade100 : Colors.grey.shade200,
                  child: Icon(
                    Icons.directions_car,
                    color: d.isOnline ? Colors.green.shade800 : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.name} (${d.plateNumber})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${d.carColor} ${d.carModel} • ${d.category.name.toUpperCase()} • Safarlar: ${d.completedTrips}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Balans: ${d.balance.toInt()} so‘m',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.teal),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Balansni to‘ldirish',
                  onPressed: () => _showTopUpDialog(d),
                  icon: const Icon(Icons.add_card_rounded, color: Colors.blue),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTariffRow(String title, TextEditingController baseCtrl, TextEditingController kmCtrl) {
    return Row(
      children: [
        SizedBox(
          width: 75,
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: TextField(
            controller: baseCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Boshlang‘ich (so‘m)',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: kmCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '1 km narxi (so‘m)',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}
