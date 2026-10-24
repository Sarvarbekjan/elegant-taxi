import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  double commissionPercent = 10.0;
  final String adminPass = "9728847";
  bool isAdminUnlocked = false;

  List<OrderModel> orders = [];
  List<DriverModel> drivers = [
    DriverModel(id: "D1", name: "Sardor Aliyev", phone: "+998 90 123 45 67", carModel: "Oq Cobalt", carNumber: "01 A 777 AA", tariffType: "STANDART"),
  ];

  void createOrder(OrderModel order) {
    orders.insert(0, order);
    SystemSound.play(SystemSoundType.click); // Ovozli signal
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
      SystemSound.play(SystemSoundType.click);
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
}

final AppState appState = AppState();

// ==================== DASTUR QOBIG'I ====================
class ElegantTaxiApp extends StatelessWidget {
  const ElegantTaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bek & Elegant Taxi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primaryColor: kBekGreen, scaffoldBackgroundColor: const Color(0xFFF5F6F8), fontFamily: 'Roboto'),
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
    appState.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _selectedRole,
        children: [
          ClientMapScreen(onOpenMenu: () => Scaffold.of(context).openDrawer()),
          const DriverTerminalScreen(),
          const Center(child: Text("Operator Paneli (Ishlab chiqilmoqda)")),
          const Center(child: Text("Admin Paneli (Ishlab chiqilmoqda)")),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: kBekGreen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.local_taxi, color: Colors.white, size: 40),
                SizedBox(height: 10),
                Text("Elegant Taxi Pro", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ListTile(leading: const Icon(Icons.map), title: const Text("Mijoz (Xarita)"), onTap: () { setState(() => _selectedRole = 0); Navigator.pop(context); }),
          ListTile(leading: const Icon(Icons.drive_eta), title: const Text("Haydovchi Terminali"), onTap: () { setState(() => _selectedRole = 1); Navigator.pop(context); }),
        ],
      ),
    );
  }
}

// ==================== 1. MIJOZ XARITASI (YANDEX MAPKIT NATIVE) ====================
class ClientMapScreen extends StatefulWidget {
  final VoidCallback onOpenMenu;
  const ClientMapScreen({super.key, required this.onOpenMenu});

  @override
  State<ClientMapScreen> createState() => _ClientMapScreenState();
}

class _ClientMapScreenState extends State<ClientMapScreen> {
  late YandexMapController _mapController;
  final List<MapObject> _mapObjects = [];

  Point _currentLocation = const Point(latitude: 41.311081, longitude: 69.240562);
  Point? _destinationLocation;
  String _toAddress = "";
  double _distanceKm = 0.0;
  int _etaMinutes = 8;
  String _selectedTariff = 'Standart';
  OrderModel? _activeOrder;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // Dinamik marker chizish (Rasm yo'qligi sababli qulamasligi uchun)
  Future<Uint8List> _createMarkerImage(Color color, bool isCar) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(20, 20), 16, paint);
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(20, 20), 8, paint);
    final picture = recorder.endRecording();
    final image = await picture.toImage(40, 40);
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
      setState(() => _currentLocation = Point(latitude: pos.latitude, longitude: pos.longitude));
      _mapController.moveCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: _currentLocation, zoom: 16)),
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.5),
      );
      _updateMapObjects();
    } catch (_) {}
  }

  // YANDEX DRIVING API (Haqiqiy yo'l chizish va masofa hisoblash)
  Future<void> _buildRoute() async {
    if (_destinationLocation == null) return;
    
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
        _distanceKm = double.parse((route.metadata.weight.distance.value / 1000).toStringAsFixed(1));
        _etaMinutes = (route.metadata.weight.time.value / 60).round();
      });

      final polyline = PolylineMapObject(
        mapId: const MapObjectId('route'),
        polyline: route.geometry,
        strokeColor: kBekGreen,
        strokeWidth: 5,
        outlineColor: Colors.black,
        outlineWidth: 1,
      );

      setState(() {
        _mapObjects.removeWhere((el) => el.mapId.value == 'route');
        _mapObjects.add(polyline);
      });

      // Avto-Zoom (yo'lni ekranga sig'dirish)
      _mapController.moveCamera(
        CameraUpdate.newGeometry(Geometry.fromBoundingBox(BoundingBox(
          southWest: Point(
            latitude: min(_currentLocation.latitude, _destinationLocation!.latitude) - 0.005,
            longitude: min(_currentLocation.longitude, _destinationLocation!.longitude) - 0.005,
          ),
          northEast: Point(
            latitude: max(_currentLocation.latitude, _destinationLocation!.latitude) + 0.005,
            longitude: max(_currentLocation.longitude, _destinationLocation!.longitude) + 0.005,
          ),
        ))),
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.5),
      );
    }
  }

  Future<void> _updateMapObjects() async {
    final startIcon = await _createMarkerImage(kBekGreen, false);
    final endIcon = await _createMarkerImage(Colors.red, false);

    setState(() {
      _mapObjects.removeWhere((el) => el.mapId.value == 'start' || el.mapId.value == 'end');
      _mapObjects.add(PlacemarkMapObject(
        mapId: const MapObjectId('start'),
        point: _currentLocation,
        icon: PlacemarkIcon.single(PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(startIcon), scale: 1.5)),
      ));
      if (_destinationLocation != null) {
        _mapObjects.add(PlacemarkMapObject(
          mapId: const MapObjectId('end'),
          point: _destinationLocation!,
          icon: PlacemarkIcon.single(PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(endIcon), scale: 1.5)),
        ));
      }
    });
  }

  void _submitOrder() {
    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Xaritadan boradigan manzilni tanlang!")));
      return;
    }
    int price = appState.stdBase + (_distanceKm * appState.stdPerKm).round();
    if (_selectedTariff == 'Komfort') price = appState.comfBase + (_distanceKm * appState.comfPerKm).round();
    
    final newOrder = OrderModel(
      id: "ORD-${Random().nextInt(9000)}",
      clientPhone: "+998 90 000 00 00",
      fromAddress: "Joriy joylashuv",
      toAddress: _toAddress.isEmpty ? "Belgilangan nuqta" : _toAddress,
      fromPoint: _currentLocation,
      toPoint: _destinationLocation!,
      tariff: _selectedTariff,
      distanceKm: _distanceKm,
      price: (price / 500).round() * 500,
      createdAt: DateTime.now(),
    );

    appState.createOrder(newOrder);
    setState(() => _activeOrder = newOrder);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // NATIVE YANDEX MAP
          YandexMap(
            mapObjects: _mapObjects,
            onMapCreated: (controller) => _mapController = controller,
            onMapTap: (point) async {
              if (_activeOrder != null && _activeOrder!.status != 'Bekor qilindi' && _activeOrder!.status != 'Yakunlandi') return;
              setState(() {
                _destinationLocation = point;
                _toAddress = "Manzil (${point.latitude.toStringAsFixed(4)})";
              });
              await _updateMapObjects();
              await _buildRoute();
            },
            logoAlignment: const MapAlignment(horizontal: HorizontalAlignment.left, vertical: VerticalAlignment.bottom),
          ),
          
          // Tepa tugmalar
          Positioned(
            top: 50, left: 16,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              onPressed: widget.onOpenMenu,
              child: const Icon(Icons.menu, color: Colors.black),
            ),
          ),
          Positioned(
            top: 50, right: 16,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              onPressed: _determinePosition,
              child: const Icon(Icons.my_location, color: kBekGreen),
            ),
          ),

          // Mijozning zamonaviy paneli
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
              ),
              child: _activeOrder != null && _activeOrder!.status != 'Bekor qilindi' && _activeOrder!.status != 'Yakunlandi'
                  ? _buildActiveOrderUI()
                  : _buildBookingUI(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Holat: ${_activeOrder!.status}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kBekGreen)),
        const SizedBox(height: 10),
        Text("Haydovchi: ${_activeOrder!.driverName ?? 'Qidirilmoqda...'}"),
        Text("Mashina: ${_activeOrder!.driverCar ?? '-'}"),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              appState.cancelOrder(_activeOrder!.id);
              setState(() => _activeOrder = null);
            },
            child: const Text("Bekor qilish", style: TextStyle(color: Colors.white)),
          ),
        )
      ],
    );
  }

  Widget _buildBookingUI() {
    int currentPrice = appState.stdBase + (_distanceKm * appState.stdPerKm).round();
    if (_selectedTariff == 'Komfort') currentPrice = appState.comfBase + (_distanceKm * appState.comfPerKm).round();
    currentPrice = (currentPrice / 500).round() * 500;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Qayerga ketyapsiz?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() => _selectedTariff = 'Standart'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTariff == 'Standart' ? Colors.green.shade50 : Colors.white,
                  border: Border.all(color: _selectedTariff == 'Standart' ? kBekGreen : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text("Standart", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedTariff = 'Komfort'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTariff == 'Komfort' ? Colors.green.shade50 : Colors.white,
                  border: Border.all(color: _selectedTariff == 'Komfort' ? kBekGreen : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text("Komfort", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBekGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _submitOrder,
            child: Text(
              _destinationLocation == null ? "Buyurtma berish" : "Buyurtma berish • $currentPrice so'm",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== 2. HAYDOVCHI TERMINALI ====================
class DriverTerminalScreen extends StatelessWidget {
  const DriverTerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pendingOrders = appState.orders.where((o) => o.status == 'Kutilmoqda').toList();
    final driver = appState.drivers.first;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Yangi tushgan buyurtmalar", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: pendingOrders.length,
                itemBuilder: (ctx, i) {
                  final ord = pendingOrders[i];
                  return Card(
                    child: ListTile(
                      title: Text("${ord.distanceKm} km • ${ord.price} so'm", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Qayerga: ${ord.toAddress}"),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: kTaxiYellow, foregroundColor: Colors.black),
                        onPressed: () => appState.updateOrderStatus(ord.id, 'Qabul qilindi', driver),
                        child: const Text("QABUL QILISH"),
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
// === KODNING OXIRI ===
