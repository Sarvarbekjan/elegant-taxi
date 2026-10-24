import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Ilova hech qachon qop-qora yoki oq ekranda qulab tushmasligi uchun himoya:
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            "Xatolik yuz berdi:\n${details.exception}",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 14),
          ),
        ),
      ),
    );
  };
  runApp(const ElegantTaxiApp());
}

const Color kBekGreen = Color(0xFF22A038);
const Color kTaxiYellow = Color(0xFFFFCC00);
const Color kDarkBg = Color(0xFF14171F);

// ==================== MODELLAR ====================
class OrderModel {
  final String id;
  final String clientPhone;
  final String fromAddress;
  final String toAddress;
  final Point fromPoint;
  final Point toPoint;
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

// ==================== GLOBAL TIZIM (STATE) ====================
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
  ];

  void playNotificationSound() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();
  }

  void createOrder(OrderModel order) {
    orders.insert(0, order);
    playNotificationSound();
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
      playNotificationSound();
      notifyListeners();
    }
  }

  void cancelOrder(String orderId) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      orders[idx].status = 'Bekor qilindi';
      playNotificationSound();
      notifyListeners();
    }
  }

  void saveTariffs(int sB, int sK, int cB, int cK, double comm) {
    stdBase = sB;
    stdPerKm = sK;
    comfBase = cB;
    comfPerKm = cK;
    commissionPercent = comm;
    notifyListeners();
  }
}

final AppState appState = AppState();

// ==================== ASOSIY DASTUR ====================
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
        title: const Text("Super-Admin Kirish"),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Parol (9728847)", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBekGreen, foregroundColor: Colors.white),
            onPressed: () {
              if (passCtrl.text.trim() == appState.adminPass) {
                appState.isAdminUnlocked = true;
                Navigator.pop(ctx);
                setState(() => _selectedRole = 3);
              }
            },
            child: const Text("KIRISH"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int pendingCount = appState.orders.where((o) => o.status == 'Kutilmoqda').length;

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      appBar: _selectedRole == 0
          ? null
          : AppBar(
              backgroundColor: kDarkBg,
              iconTheme: const IconThemeData(color: kTaxiYellow),
              title: Text(
                _selectedRole == 1
                    ? "HAYDOVCHI TERMINALI"
                    : _selectedRole == 2
                        ? "OPERATOR MARKAZI"
                        : "SUPER-ADMIN",
                style: const TextStyle(color: kTaxiYellow, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () => setState(() => _selectedRole = 0),
                  icon: const Icon(Icons.map, color: Colors.white, size: 18),
                  label: const Text("Xarita", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(backgroundColor: kBekGreen, child: Icon(Icons.person, color: Colors.white)),
                title: const Text("Sarvarbek", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text("Bonus: ${appState.clientBonus} so'm"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.map, color: kBekGreen),
                title: const Text("Mijoz (Taksi chaqirish)"),
                selected: _selectedRole == 0,
                onTap: () => _selectRole(0),
              ),
              ListTile(
                leading: const Icon(Icons.local_taxi, color: Colors.green),
                title: const Text("Haydovchi rejimi"),
                trailing: pendingCount > 0
                    ? CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.red,
                        child: Text("$pendingCount", style: const TextStyle(color: Colors.white, fontSize: 11)),
                      )
                    : null,
                selected: _selectedRole == 1,
                onTap: () => _selectRole(1),
              ),
              ListTile(
                leading: const Icon(Icons.headset_mic, color: Colors.orange),
                title: const Text("Operator paneli"),
                selected: _selectedRole == 2,
                onTap: () => _selectRole(2),
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.redAccent),
                title: const Text("Super-Admin"),
                selected: _selectedRole == 3,
                onTap: () => _selectRole(3),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedRole,
        children: [
          ClientMapScreen(
            onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onQuickRoleSwitch: (r) => setState(() => _selectedRole = r),
          ),
          const DriverTerminalScreen(),
          const OperatorView(),
          const AdminView(),
        ],
      ),
    );
  }
}

// ==================== 1. MIJOZ XARITASI (YANDEX MAPKIT NATIVE) ====================
class ClientMapScreen extends StatefulWidget {
  final VoidCallback onOpenMenu;
  final ValueChanged<int> onQuickRoleSwitch;

  const ClientMapScreen({
    super.key,
    required this.onOpenMenu,
    required this.onQuickRoleSwitch,
  });

  @override
  State<ClientMapScreen> createState() => _ClientMapScreenState();
}

class _ClientMapScreenState extends State<ClientMapScreen> {
  YandexMapController? _mapController; // NULL-SAFE CONTROLLER (Qulashdan himoya)
  final List<MapObject> _mapObjects = [];

  Point _currentLocation = const Point(latitude: 37.8267, longitude: 67.5975);
  Point? _destinationLocation;
  String _fromAddress = "Joriy joylashuv";
  String _toAddress = "";
  double _distanceKm = 0.0;
  int _etaMinutes = 5;
  String _selectedTariff = 'Standart';
  OrderModel? _activeOrder;

  Future<Uint8List> _createMarkerImage(Color color, String label) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(30, 30), 26, paint);
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(30, 30), 18, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(30 - textPainter.width / 2, 30 - textPainter.height / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(60, 60);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
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
      if (!mounted) return;
      setState(() {
        _currentLocation = Point(latitude: pos.latitude, longitude: pos.longitude);
        _fromAddress = "Joriy joylashuv (${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)})";
      });
      if (_mapController != null) {
        await _mapController!.moveCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: _currentLocation, zoom: 15.5)),
          animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.2),
        );
      }
      await _updateMapObjects();
    } catch (_) {}
  }

  double _calculateStraightDistance(Point p1, Point p2) {
    const double R = 6371.0;
    double dLat = (p2.latitude - p1.latitude) * pi / 180.0;
    double dLon = (p2.longitude - p1.longitude) * pi / 180.0;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(p1.latitude * pi / 180.0) * cos(p2.latitude * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return max(1.0, double.parse((R * c * 1.3).toStringAsFixed(1)));
  }

  Future<void> _buildRoute() async {
    if (_destinationLocation == null) return;

    try {
      var resultWithSession = YandexDriving.requestRoutes(
        points: [
          RequestPoint(point: _currentLocation, requestPointType: RequestPointType.wayPoint),
          RequestPoint(point: _destinationLocation!, requestPointType: RequestPointType.wayPoint),
        ],
        drivingOptions: const DrivingOptions(initialAzimuth: 0, routesCount: 1, avoidTolls: true),
      );

      final result = await resultWithSession.result;
      if (result.routes != null && result.routes!.isNotEmpty) {
        final route = result.routes!.first;
        setState(() {
          _distanceKm = double.parse(((route.metadata.weight.distance.value ?? 1000.0) / 1000).toStringAsFixed(1));
          _etaMinutes = max(3, ((route.metadata.weight.time.value ?? 180.0) / 60).round());
        });

        final polyline = PolylineMapObject(
          mapId: const MapObjectId('route'),
          polyline: Polyline(points: route.geometry),
          strokeColor: kBekGreen,
          strokeWidth: 5,
          outlineColor: Colors.black,
          outlineWidth: 1,
        );

        setState(() {
          _mapObjects.removeWhere((el) => el.mapId.value == 'route');
          _mapObjects.add(polyline);
        });
      } else {
        _drawFallbackRoute();
      }
    } catch (_) {
      _drawFallbackRoute();
    }

    if (_mapController != null) {
      await _mapController!.moveCamera(
        CameraUpdate.newGeometry(
          Geometry.fromBoundingBox(
            BoundingBox(
              southWest: Point(
                latitude: min(_currentLocation.latitude, _destinationLocation!.latitude) - 0.005,
                longitude: min(_currentLocation.longitude, _destinationLocation!.longitude) - 0.005,
              ),
              northEast: Point(
                latitude: max(_currentLocation.latitude, _destinationLocation!.latitude) + 0.005,
                longitude: max(_currentLocation.longitude, _destinationLocation!.longitude) + 0.005,
              ),
            ),
          ),
        ),
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.2),
      );
    }
  }

  void _drawFallbackRoute() {
    if (_destinationLocation == null) return;
    final dist = _calculateStraightDistance(_currentLocation, _destinationLocation!);
    setState(() {
      _distanceKm = dist;
      _etaMinutes = max(3, (dist * 2).round());
      _mapObjects.removeWhere((el) => el.mapId.value == 'route');
      _mapObjects.add(
        PolylineMapObject(
          mapId: const MapObjectId('route'),
          polyline: Polyline(points: [_currentLocation, _destinationLocation!]),
          strokeColor: kBekGreen,
          strokeWidth: 5,
        ),
      );
    });
  }

  Future<void> _updateMapObjects() async {
    final startIcon = await _createMarkerImage(kBekGreen, "A");
    final endIcon = await _createMarkerImage(Colors.red, "B");
    final taxiIcon = await _createMarkerImage(kTaxiYellow, "T");

    if (!mounted) return;
    setState(() {
      _mapObjects.removeWhere((el) => el.mapId.value != 'route');
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('start'),
          point: _currentLocation,
          icon: PlacemarkIcon.single(PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(startIcon), scale: 1.1)),
        ),
      );
      // Atrofdagi jonli taksilar
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('taxi_1'),
          point: Point(latitude: _currentLocation.latitude + 0.003, longitude: _currentLocation.longitude + 0.002),
          icon: PlacemarkIcon.single(PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(taxiIcon), scale: 0.9)),
        ),
      );
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('taxi_2'),
          point: Point(latitude: _currentLocation.latitude - 0.002, longitude: _currentLocation.longitude + 0.004),
          icon: PlacemarkIcon.single(PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(taxiIcon), scale: 0.9)),
        ),
      );
      if (_destinationLocation != null) {
        _mapObjects.add(
          PlacemarkMapObject(
            mapId: const MapObjectId('end'),
            point: _destinationLocation!,
            icon: PlacemarkIcon.single(PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(endIcon), scale: 1.1)),
          ),
        );
      }
    });
  }

  int _getPrice(String tariff) {
    int base = appState.stdBase;
    int perKm = appState.stdPerKm;
    if (tariff == 'Komfort') {
      base = appState.comfBase;
      perKm = appState.comfPerKm;
    } else if (tariff == 'Dostavka') {
      base = appState.delivBase;
      perKm = appState.delivPerKm;
    }
    if (_destinationLocation == null) return base;
    return ((base + _distanceKm * perKm) / 500).round() * 500;
  }

  void _submitOrder() {
    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Iltimos, xaritadan boradigan manzilingizni bosing!"), backgroundColor: Colors.red),
      );
      return;
    }

    final newOrder = OrderModel(
      id: "ORD-${Random().nextInt(9000) + 1000}",
      clientPhone: "+998 90 267 25 80",
      fromAddress: _fromAddress,
      toAddress: _toAddress,
      fromPoint: _currentLocation,
      toPoint: _destinationLocation!,
      tariff: _selectedTariff,
      distanceKm: _distanceKm,
      price: _getPrice(_selectedTariff),
      createdAt: DateTime.now(),
    );

    appState.createOrder(newOrder);
    setState(() => _activeOrder = newOrder);
  }

  @override
  Widget build(BuildContext context) {
    final int pendingCount = appState.orders.where((o) => o.status == 'Kutilmoqda').length;

    return Scaffold(
      body: Stack(
        children: [
          YandexMap(
            mapObjects: _mapObjects,
            onMapCreated: (controller) async {
              _mapController = controller;
              await _mapController!.moveCamera(
                CameraUpdate.newCameraPosition(CameraPosition(target: _currentLocation, zoom: 15.0)),
              );
              await _updateMapObjects();
              await _determinePosition();
            },
            onMapTap: (point) async {
              if (_activeOrder != null &&
                  _activeOrder!.status != 'Bekor qilindi' &&
                  _activeOrder!.status != 'Yakunlandi') return;
              setState(() {
                _destinationLocation = point;
                _toAddress = "Manzil (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})";
              });
              await _updateMapObjects();
              await _buildRoute();
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            child: FloatingActionButton.small(
              heroTag: "menu_btn",
              backgroundColor: Colors.white,
              onPressed: widget.onOpenMenu,
              child: const Icon(Icons.menu, color: kBekGreen),
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
                      style: ElevatedButton.styleFrom(backgroundColor: kBekGreen, foregroundColor: Colors.white),
                      onPressed: () => widget.onQuickRoleSwitch(1),
                      icon: const Icon(Icons.local_taxi, size: 16),
                      label: Text("Haydovchi ($pendingCount)"),
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
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16)],
              ),
              child: _activeOrder != null && _activeOrder!.status != 'Bekor qilindi'
                  ? _buildActiveOrderUI()
                  : _buildBookingUI(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderUI() {
    final st = _activeOrder!.status;
    if (st == 'Yakunlandi') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: kBekGreen, size: 42),
          const SizedBox(height: 6),
          const Text("Safar muvaffaqiyatli yakunlandi!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text("To'lov: ${_activeOrder!.price} so'm (${_activeOrder!.distanceKm} km)"),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kTaxiYellow, foregroundColor: Colors.black),
              onPressed: () {
                setState(() {
                  _activeOrder = null;
                  _destinationLocation = null;
                  _toAddress = "";
                  _mapObjects.removeWhere((el) => el.mapId.value == 'route' || el.mapId.value == 'end');
                });
              },
              child: const Text("YANGI BUYURTMA BERISH", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const CircularProgressIndicator(color: kBekGreen, strokeWidth: 3),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Holat: $st", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Haydovchi: ${_activeOrder!.driverName ?? 'Qidirilmoqda...'}"),
                  if (_activeOrder!.driverCar != null) Text(_activeOrder!.driverCar!),
                ],
              ),
            ),
            Text("${_activeOrder!.price} so'm", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBekGreen)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              appState.cancelOrder(_activeOrder!.id);
              setState(() => _activeOrder = null);
            },
            child: const Text("Buyurtmani bekor qilish"),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.my_location, color: kBekGreen, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_fromAddress, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        const Divider(height: 16),
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _toAddress.isEmpty ? "Qayerga ketyapsiz? (Xaritadan bosing)" : _toAddress,
                style: TextStyle(color: _toAddress.isEmpty ? Colors.grey : Colors.black, fontWeight: FontWeight.w600),
              ),
            ),
            if (_destinationLocation != null)
              Text("$_distanceKm km • ~$_etaMinutes daq", style: const TextStyle(color: kBekGreen, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _tariffCard("Standart", Icons.local_taxi),
              const SizedBox(width: 10),
              _tariffCard("Komfort", Icons.directions_car),
              const SizedBox(width: 10),
              _tariffCard("Dostavka", Icons.local_shipping),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBekGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            onPressed: _submitOrder,
            child: Text(
              _destinationLocation == null
                  ? "Buyurtma berish"
                  : "Buyurtma berish • ${_getPrice(_selectedTariff)} so'm",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tariffCard(String title, IconData icon) {
    final bool selected = _selectedTariff == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedTariff = title),
      child: Container(
        width: 115,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? kBekGreen : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? kBekGreen : Colors.black54),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text("${_getPrice(title)} so'm", style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

// ==================== 2. HAYDOVCHI TERMINALI ====================
class DriverTerminalScreen extends StatelessWidget {
  const DriverTerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driver = appState.drivers.first;
    final pendingOrders = appState.orders.where((o) => o.status == 'Kutilmoqda').toList();
    final activeOrders = appState.orders
        .where((o) => o.status != 'Kutilmoqda' && o.status != 'Yakunlandi' && o.status != 'Bekor qilindi')
        .toList();

    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kDarkBg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("${driver.carModel} • ${driver.carNumber}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                Text("Balans: ${driver.balance} so'm", style: const TextStyle(color: kTaxiYellow, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (activeOrders.isNotEmpty) ...[
            const Text("Faol buyurtma:", style: TextStyle(fontWeight: FontWeight.bold)),
            ...activeOrders.map((ord) => Card(
                  color: Colors.green.shade50,
                  child: ListTile(
                    title: Text("${ord.toAddress} (${ord.price} so'm)", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Holat: ${ord.status}"),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kBekGreen, foregroundColor: Colors.white),
                      onPressed: () {
                        String next = 'Yetib keldi';
                        if (ord.status == 'Yetib keldi') next = 'Safarda';
                        if (ord.status == 'Safarda') next = 'Yakunlandi';
                        appState.updateOrderStatus(ord.id, next, driver);
                      },
                      child: Text(ord.status == 'Safarda' ? "YAKUNLASH" : "KEYINGI BOSQICH"),
                    ),
                  ),
                )),
            const SizedBox(height: 12),
          ],
          const Text("Yangi buyurtmalar:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Expanded(
            child: pendingOrders.isEmpty
                ? const Center(child: Text("Hozircha yangi buyurtmalar yo'q...", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: pendingOrders.length,
                    itemBuilder: (ctx, i) {
                      final ord = pendingOrders[i];
                      return Card(
                        child: ListTile(
                          title: Text("${ord.tariff} • ${ord.price} so'm", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Manzil: ${ord.toAddress} (${ord.distanceKm} km)"),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: kTaxiYellow, foregroundColor: Colors.black),
                            onPressed: () => appState.updateOrderStatus(ord.id, 'Qabul qilindi', driver),
                            child: const Text("QABUL QILISH"),
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

// ==================== 3. OPERATOR PANELI ====================
class OperatorView extends StatefulWidget {
  const OperatorView({super.key});
  @override
  State<OperatorView> createState() => _OperatorViewState();
}

class _OperatorViewState extends State<OperatorView> {
  final TextEditingController _toCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        children: [
          TextField(
            controller: _toCtrl,
            decoration: const InputDecoration(labelText: "Qayerga borish manzili", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kTaxiYellow, foregroundColor: Colors.black),
              onPressed: () {
                if (_toCtrl.text.isEmpty) return;
                appState.createOrder(
                  OrderModel(
                    id: "OP-${Random().nextInt(900)}",
                    clientPhone: "+998 90 123 45 67",
                    fromAddress: "Markaziy bozor",
                    toAddress: _toCtrl.text,
                    fromPoint: const Point(latitude: 37.8267, longitude: 67.5975),
                    toPoint: const Point(latitude: 37.8367, longitude: 67.6075),
                    tariff: "Standart",
                    distanceKm: 3.0,
                    price: 10000,
                    createdAt: DateTime.now(),
                  ),
                );
                _toCtrl.clear();
              },
              child: const Text("HAYDOVCHILARGA YUBORISH"),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 4. ADMIN PANELI ====================
class AdminView extends StatelessWidget {
  const AdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Standart boshlang'ich: ${appState.stdBase} so'm", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text("1 km narxi: ${appState.stdPerKm} so'm", style: const TextStyle(fontSize: 16)),
          const Divider(height: 24),
          const Text("Haydovchilar ro'yxati:", style: TextStyle(fontWeight: FontWeight.bold)),
          ...appState.drivers.map((d) => ListTile(
                title: Text(d.name),
                subtitle: Text("${d.carModel} • Balans: ${d.balance} so'm"),
              )),
        ],
      ),
    );
  }
}
