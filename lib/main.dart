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
  String status; // Kutilmoqda, Qabul qilindi, Yetib keldi, Safarda, Yakunlandi, Bekor qilindi
  String? driverId;
  String? driverName;
  String? driverCar;
  String? driverPhone;
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
    this.driverId,
    this.driverName,
    this.driverCar,
    this.driverPhone,
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
    this.tariffType = 'Standart',
    this.trips = 144,
    this.balance = 584200,
    this.isOnline = true,
  });
}

// ==================== GLOBAL TIZIM (STATE VA OVOZ) ====================
class AppState extends ChangeNotifier {
  static const MethodChannel _soundChannel = MethodChannel('com.example.elegant_taxi/sound');

  int stdBase = 4000;
  int stdPerKm = 2000;
  int comfBase = 5000;
  int comfPerKm = 3000;
  int delivBase = 6000;
  int delivPerKm = 2500;
  double commissionPercent = 10.0;

  String adminPass = "9728847";
  bool isAdminUnlocked = false;
  int clientBonus = 10000;
  bool useBonus = false;
  int activeDriverIndex = 0;

  List<OrderModel> orders = [];
  List<DriverModel> drivers = [
    DriverModel(
      id: "D1",
      name: "Sardor Aliyev",
      phone: "+998 90 123 45 67",
      carModel: "Oq Chevrolet Cobalt",
      carNumber: "01 A 777 AA",
      tariffType: "Standart",
      trips: 144,
      balance: 584200,
    ),
    DriverModel(
      id: "D2",
      name: "Jasur Karimov",
      phone: "+998 90 987 65 43",
      carModel: "Qora Chevrolet Gentra",
      carNumber: "01 B 555 BB",
      tariffType: "Komfort",
      trips: 98,
      balance: 120000,
    ),
  ];

  Future<void> playNotificationSound() async {
    try {
      HapticFeedback.heavyImpact();
      await _soundChannel.invokeMethod('playSound');
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
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
      orders[idx].driverId = driver.id;
      orders[idx].driverName = driver.name;
      orders[idx].driverPhone = driver.phone;
      orders[idx].driverCar = "${driver.carModel} • ${driver.carNumber}";
      if (newStatus == 'Yakunlandi') {
        int comm = ((orders[idx].price * commissionPercent) / 100).round();
        driver.balance -= comm;
        driver.trips += 1;
        clientBonus += ((orders[idx].price * 0.03) / 100).round() * 100;
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
    playNotificationSound();
    notifyListeners();
  }

  void addDriver(String name, String phone, String car, String num, String tariff, int bal) {
    drivers.add(DriverModel(
      id: "D${drivers.length + 1}",
      name: name,
      phone: phone,
      carModel: car,
      carNumber: num,
      tariffType: tariff,
      trips: 0,
      balance: bal,
    ));
    notifyListeners();
  }

  void topUpDriverBalance(String driverId, int amount) {
    final idx = drivers.indexWhere((d) => d.id == driverId);
    if (idx != -1) {
      drivers[idx].balance += amount;
      notifyListeners();
    }
  }
}

final AppState appState = AppState();

// ==================== ASOSIY DASTUR ====================
class ElegantTaxiApp extends StatelessWidget {
  const ElegantTaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elegant Taxi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: kBekGreen,
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
        fontFamily: 'Roboto',
        useMaterial3: true,
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

  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _switchRoleDirect(int roleIndex) {
    _hideKeyboard();
    if (roleIndex == 3 && !appState.isAdminUnlocked) {
      _showAdminPasswordDialog();
    } else {
      setState(() => _selectedRole = roleIndex);
    }
  }

  void _selectRoleFromDrawer(int roleIndex) {
    Navigator.pop(context);
    _switchRoleDirect(roleIndex);
  }

  void _showAdminPasswordDialog() {
    final TextEditingController passCtrl = TextEditingController();
    bool obscure = true;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.lock_outline, color: kBekGreen),
                SizedBox(width: 8),
                Text("Boshqaruv paneli", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Maxfiy parolni kiriting",
                    errorText: errorText,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _hideKeyboard();
                  Navigator.pop(ctx);
                },
                child: const Text("Bekor qilish", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBekGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (passCtrl.text.trim() == appState.adminPass) {
                    appState.isAdminUnlocked = true;
                    _hideKeyboard();
                    Navigator.pop(ctx);
                    setState(() => _selectedRole = 3);
                  } else {
                    HapticFeedback.vibrate();
                    setDialogState(() => errorText = "Parol noto'g'ri!");
                  }
                },
                child: const Text("KIRISH"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder barcha 4 ta oynani real-time yangilab turishni kafolatlaydi!
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final int pendingCount = appState.orders.where((o) => o.status == 'Kutilmoqda').length;

        return GestureDetector(
          onTap: _hideKeyboard,
          child: Scaffold(
            key: _scaffoldKey,
            resizeToAvoidBottomInset: true,
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
                              : "SUPER-ADMIN PANELI",
                      style: const TextStyle(color: kTaxiYellow, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    actions: [
                      TextButton.icon(
                        onPressed: () => _switchRoleDirect(0),
                        icon: const Icon(Icons.map, color: Colors.white, size: 18),
                        label: const Text("Xarita", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
            drawer: Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: kBekGreen.withOpacity(0.08),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 26,
                            backgroundColor: kBekGreen,
                            child: Icon(Icons.person, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Sarvarbek", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                Text(
                                  "Bonus balans: ${appState.clientBonus} so'm",
                                  style: const TextStyle(color: kBekGreen, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.map, color: kBekGreen),
                      title: const Text("Mijoz (Taksi chaqirish)"),
                      selected: _selectedRole == 0,
                      onTap: () => _selectRoleFromDrawer(0),
                    ),
                    ListTile(
                      leading: const Icon(Icons.local_taxi, color: Colors.green),
                      title: const Text("Haydovchi terminali"),
                      trailing: pendingCount > 0
                          ? CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Text(
                                "$pendingCount",
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            )
                          : null,
                      selected: _selectedRole == 1,
                      onTap: () => _selectRoleFromDrawer(1),
                    ),
                    ListTile(
                      leading: const Icon(Icons.headset_mic, color: Colors.orange),
                      title: const Text("Dispetcher (Operator)"),
                      selected: _selectedRole == 2,
                      onTap: () => _selectRoleFromDrawer(2),
                    ),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings, color: Colors.redAccent),
                      title: const Text("Super-Admin"),
                      trailing: Icon(
                        appState.isAdminUnlocked ? Icons.lock_open : Icons.lock,
                        size: 18,
                        color: Colors.grey,
                      ),
                      selected: _selectedRole == 3,
                      onTap: () => _selectRoleFromDrawer(3),
                    ),
                  ],
                ),
              ),
            ),
            body: IndexedStack(
              index: _selectedRole,
              children: [
                ClientMapScreen(
                  onOpenMenu: () {
                    _hideKeyboard();
                    _scaffoldKey.currentState?.openDrawer();
                  },
                  onQuickRoleSwitch: _switchRoleDirect,
                ),
                DriverTerminalScreen(state: appState),
                OperatorView(state: appState),
                AdminView(state: appState),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== 1. MIJOZ XARITASI (YANDEX MAPKIT + GEOCODER) ====================
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
  YandexMapController? _mapController;
  final List<MapObject> _mapObjects = [];

  Point _currentLocation = const Point(latitude: 55.751244, longitude: 37.618423);
  Point? _destinationLocation;
  String _fromAddress = "Joylashuv aniqlanmoqda...";
  String _toAddress = "";
  double _distanceKm = 0.0;
  int _etaMinutes = 5;
  String _selectedTariff = 'Standart';
  String? _activeOrderId;
  bool _isSearchingAddress = false;

  OrderModel? get _activeOrder {
    if (_activeOrderId == null) return null;
    try {
      return appState.orders.firstWhere((o) => o.id == _activeOrderId);
    } catch (_) {
      return null;
    }
  }

  // Koordinatani haqiqiy ko'cha nomiga aylantirish (Yandex Geocoder)
  Future<String> _reverseGeocode(Point point) async {
    try {
      final sessionWithRes = YandexSearch.searchByPoint(
        point: point,
        zoom: 17,
        searchOptions: const SearchOptions(
          searchType: SearchType.geo,
          geometry: false,
        ),
      );
      final res = await sessionWithRes.result;
      if (res.items != null && res.items!.isNotEmpty) {
        final name = res.items!.first.name;
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}
    return "Belgilangan nuqta (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})";
  }

  Future<Uint8List> _createMarkerImage(Color color, String label) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(32, 32), 28, paint);
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(32, 32), 19, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(32 - textPainter.width / 2, 32 - textPainter.height / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(64, 64);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _determinePosition({bool immediateJump = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _fromAddress = "GPS o'chirilgan (Joriy nuqta)");
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;

      final pt = Point(latitude: pos.latitude, longitude: pos.longitude);
      setState(() => _currentLocation = pt);

      if (_mapController != null) {
        await _mapController!.moveCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: _currentLocation, zoom: 16.0)),
          animation: immediateJump ? null : const MapAnimation(type: MapAnimationType.smooth, duration: 1.0),
        );
      }

      await _updateMapObjects();
      final addr = await _reverseGeocode(pt);
      if (mounted) {
        setState(() => _fromAddress = addr);
      }
    } catch (_) {
      if (mounted) setState(() => _fromAddress = "Joriy joylashuv");
    }
  }

  double _calculateStraightDistance(Point p1, Point p2) {
    const double R = 6371.0;
    double dLat = (p2.latitude - p1.latitude) * pi / 180.0;
    double dLon = (p2.longitude - p1.longitude) * pi / 180.0;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(p1.latitude * pi / 180.0) * cos(p2.latitude * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return max(0.5, double.parse((R * c * 1.3).toStringAsFixed(1)));
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
          _etaMinutes = max(2, ((route.metadata.weight.time.value ?? 180.0) / 60).round());
        });

        final polyline = PolylineMapObject(
          mapId: const MapObjectId('route'),
          polyline: Polyline(points: route.geometry),
          strokeColor: kBekGreen,
          strokeWidth: 5.5,
          outlineColor: Colors.black87,
          outlineWidth: 1.2,
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
                latitude: min(_currentLocation.latitude, _destinationLocation!.latitude) - 0.004,
                longitude: min(_currentLocation.longitude, _destinationLocation!.longitude) - 0.004,
              ),
              northEast: Point(
                latitude: max(_currentLocation.latitude, _destinationLocation!.latitude) + 0.004,
                longitude: max(_currentLocation.longitude, _destinationLocation!.longitude) + 0.004,
              ),
            ),
          ),
        ),
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.0),
      );
    }
  }

  void _drawFallbackRoute() {
    if (_destinationLocation == null) return;
    final dist = _calculateStraightDistance(_currentLocation, _destinationLocation!);
    setState(() {
      _distanceKm = dist;
      _etaMinutes = max(2, (dist * 2.5).round());
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
          icon: PlacemarkIcon.single(PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(startIcon), scale: 1.0)),
        ),
      );
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('taxi_1'),
          point: Point(latitude: _currentLocation.latitude + 0.0022, longitude: _currentLocation.longitude + 0.0018),
          icon: PlacemarkIcon.single(PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(taxiIcon), scale: 0.85)),
        ),
      );
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('taxi_2'),
          point: Point(latitude: _currentLocation.latitude - 0.0018, longitude: _currentLocation.longitude + 0.0028),
          icon: PlacemarkIcon.single(PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(taxiIcon), scale: 0.85)),
        ),
      );
      if (_destinationLocation != null) {
        _mapObjects.add(
          PlacemarkMapObject(
            mapId: const MapObjectId('end'),
            point: _destinationLocation!,
            icon: PlacemarkIcon.single(PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(endIcon), scale: 1.0)),
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
    int raw = ((base + _distanceKm * perKm) / 500).round() * 500;
    if (appState.useBonus && appState.clientBonus > 0) {
      raw = max(2000, raw - min(raw - 2000, appState.clientBonus));
    }
    return raw;
  }

  void _showManualDestinationDialog() {
    final TextEditingController searchCtrl = TextEditingController(text: _toAddress);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Boradigan manzilni kiriting", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 12),
            TextField(
              controller: searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Masalan: Markaziy bozor, Aeroport...",
                prefixIcon: const Icon(Icons.search, color: kBekGreen),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kBekGreen, foregroundColor: Colors.white),
                onPressed: () async {
                  final text = searchCtrl.text.trim();
                  Navigator.pop(ctx);
                  if (text.isEmpty) return;

                  setState(() {
                    _isSearchingAddress = true;
                    _toAddress = text;
                  });

                  try {
                    final session = YandexSearch.searchByText(
                      searchText: text,
                      geometry: Geometry.fromBoundingBox(
                        BoundingBox(
                          southWest: Point(
                            latitude: _currentLocation.latitude - 0.2,
                            longitude: _currentLocation.longitude - 0.2,
                          ),
                          northEast: Point(
                            latitude: _currentLocation.latitude + 0.2,
                            longitude: _currentLocation.longitude + 0.2,
                          ),
                        ),
                      ),
                      searchOptions: const SearchOptions(searchType: SearchType.geo),
                    );
                    final res = await session.result;
                    if (res.items != null &&
                        res.items!.isNotEmpty &&
                        res.items!.first.geometry.isNotEmpty &&
                        res.items!.first.geometry.first.point != null) {
                      _destinationLocation = res.items!.first.geometry.first.point!;
                      _toAddress = res.items!.first.name;
                    } else {
                      _destinationLocation ??= Point(
                        latitude: _currentLocation.latitude + 0.008,
                        longitude: _currentLocation.longitude + 0.008,
                      );
                    }
                  } catch (_) {
                    _destinationLocation ??= Point(
                      latitude: _currentLocation.latitude + 0.008,
                      longitude: _currentLocation.longitude + 0.008,
                    );
                  }

                  setState(() => _isSearchingAddress = false);
                  await _updateMapObjects();
                  await _buildRoute();
                },
                child: const Text("MANZILNI TASDIQLASH", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitOrder() {
    if (_destinationLocation == null) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Iltimos, xaritadan boradigan manzilingizni bosing yoki yozing!"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
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
    setState(() => _activeOrderId = newOrder.id);
  }

  @override
  Widget build(BuildContext context) {
    final int pendingCount = appState.orders.where((o) => o.status == 'Kutilmoqda').length;
    final OrderModel? activeOrd = _activeOrder;

    return Scaffold(
      body: Stack(
        children: [
          YandexMap(
            mapObjects: _mapObjects,
            onMapCreated: (controller) async {
              _mapController = controller;
              await _determinePosition(immediateJump: true);
            },
            onMapTap: (point) async {
              FocusManager.instance.primaryFocus?.unfocus();
              if (activeOrd != null &&
                  activeOrd.status != 'Bekor qilindi' &&
                  activeOrd.status != 'Yakunlandi') return;

              setState(() {
                _destinationLocation = point;
                _isSearchingAddress = true;
                _toAddress = "Manzil aniqlanmoqda...";
              });

              await _updateMapObjects();
              await _buildRoute();
              final addrName = await _reverseGeocode(point);
              if (mounted) {
                setState(() {
                  _toAddress = addrName;
                  _isSearchingAddress = false;
                });
              }
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBekGreen,
                        foregroundColor: Colors.white,
                        elevation: 4,
                      ),
                      onPressed: () => widget.onQuickRoleSwitch(1),
                      icon: const Icon(Icons.notifications_active, size: 17),
                      label: Text("Haydovchi ($pendingCount)", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                FloatingActionButton.small(
                  heroTag: "gps_btn",
                  backgroundColor: Colors.white,
                  onPressed: () => _determinePosition(immediateJump: false),
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
              child: activeOrd != null && activeOrd.status != 'Bekor qilindi'
                  ? _buildActiveOrderUI(activeOrd)
                  : _buildBookingUI(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderUI(OrderModel ord) {
    final st = ord.status;
    if (st == 'Yakunlandi') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: kBekGreen, size: 48),
          const SizedBox(height: 6),
          const Text("Safar muvaffaqiyatli yakunlandi!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 4),
          Text("To'lov summasi: ${ord.price} so'm (${ord.distanceKm} km)", style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kTaxiYellow, foregroundColor: Colors.black),
              onPressed: () {
                setState(() {
                  _activeOrderId = null;
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

    Color badgeColor = Colors.orange;
    String statusTitle = "Haydovchi qidirilmoqda...";
    if (st == 'Qabul qilindi') {
      badgeColor = Colors.blue;
      statusTitle = "Haydovchi yo'lga chiqdi!";
    } else if (st == 'Yetib keldi') {
      badgeColor = kBekGreen;
      statusTitle = "Haydovchi sizni kutmoqda!";
    } else if (st == 'Safarda') {
      badgeColor = Colors.purple;
      statusTitle = "Safar davom etmoqda...";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(st.toUpperCase(), style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const Spacer(),
            Text("${ord.price} so'm", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kBekGreen)),
          ],
        ),
        const SizedBox(height: 10),
        Text(statusTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        if (ord.driverName != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const CircleAvatar(backgroundColor: kBekGreen, child: Icon(Icons.drive_eta, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ord.driverName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(ord.driverCar ?? "", style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else
          const LinearProgressIndicator(color: kBekGreen, backgroundColor: Colors.black12),
        const SizedBox(height: 12),
        if (st != 'Safarda')
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                appState.cancelOrder(ord.id);
                setState(() => _activeOrderId = null);
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
            const Icon(Icons.my_location, color: kBekGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _fromAddress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
        const Divider(height: 18),
        InkWell(
          onTap: _showManualDestinationDialog,
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isSearchingAddress
                      ? "Manzil qidirilmoqda..."
                      : (_toAddress.isEmpty ? "Qayerga ketyapsiz? (Xaritadan bosing yoki yozing)" : _toAddress),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _toAddress.isEmpty ? Colors.grey.shade600 : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_destinationLocation != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    "$_distanceKm km • ~$_etaMinutes daq",
                    style: const TextStyle(color: kBekGreen, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
            ],
          ),
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
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBekGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              elevation: 2,
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
        width: 118,
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

// ==================== 2. HAYDOVCHI TERMINALI (100% REAL-TIME) ====================
class DriverTerminalScreen extends StatelessWidget {
  final AppState state;
  const DriverTerminalScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final driver = state.drivers[state.activeDriverIndex];
    final pendingOrders = state.orders.where((o) => o.status == 'Kutilmoqda').toList();
    final activeOrders = state.orders
        .where((o) =>
            o.driverId == driver.id &&
            o.status != 'Kutilmoqda' &&
            o.status != 'Yakunlandi' &&
            o.status != 'Bekor qilindi')
        .toList();

    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kDarkBg, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driver.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("${driver.carModel} • ${driver.carNumber}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${driver.balance} so'm", style: const TextStyle(color: kTaxiYellow, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("Safarlar: ${driver.trips} ta", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                if (state.drivers.length > 1) ...[
                  const Divider(color: Colors.white24, height: 18),
                  Row(
                    children: [
                      const Text("Faol haydovchi: ", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            dropdownColor: kDarkBg,
                            value: state.activeDriverIndex,
                            isDense: true,
                            style: const TextStyle(color: kTaxiYellow, fontWeight: FontWeight.bold, fontSize: 13),
                            items: List.generate(
                              state.drivers.length,
                              (idx) => DropdownMenuItem(
                                value: idx,
                                child: Text("${state.drivers[idx].name} (${state.drivers[idx].tariffType})"),
                              ),
                            ),
                            onChanged: (val) {
                              if (val != null) {
                                state.activeDriverIndex = val;
                                state.notifyListeners();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (activeOrders.isNotEmpty) ...[
            const Text("Joriy bajarilayotgan buyurtma:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kBekGreen)),
            const SizedBox(height: 6),
            ...activeOrders.map((ord) => Card(
                  color: Colors.green.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: kBekGreen, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("${ord.tariff} • ${ord.distanceKm} km", style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text("${ord.price} so'm", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBekGreen)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text("Qayerdan: ${ord.fromAddress}", style: const TextStyle(fontSize: 13)),
                        Text("Qayerga: ${ord.toAddress}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: kBekGreen, foregroundColor: Colors.white),
                                onPressed: () {
                                  String next = 'Yetib keldi';
                                  if (ord.status == 'Yetib keldi') next = 'Safarda';
                                  if (ord.status == 'Safarda') next = 'Yakunlandi';
                                  state.updateOrderStatus(ord.id, next, driver);
                                },
                                child: Text(
                                  ord.status == 'Qabul qilindi'
                                      ? "YETIB KELDIM"
                                      : ord.status == 'Yetib keldi'
                                          ? "SAFARNI BOSHLASH"
                                          : "SAFARNI YAKUNLASH",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Yangi buyurtmalar (${pendingOrders.length}):", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (pendingOrders.isNotEmpty)
                const Text("Jonli efir", style: TextStyle(color: kBekGreen, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: pendingOrders.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radar, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text("Yangi buyurtmalar kutilmoqda...", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: pendingOrders.length,
                    itemBuilder: (ctx, i) {
                      final ord = pendingOrders[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: kTaxiYellow, borderRadius: BorderRadius.circular(6)),
                                    child: Text(ord.tariff, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  Text("${ord.price} so'm", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: kBekGreen)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text("📍 Oladi: ${ord.fromAddress}", style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 3),
                              Text("🏁 Boradi: ${ord.toAddress}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text("Masofa: ${ord.distanceKm} km • Mijoz: ${ord.clientPhone}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kBekGreen,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => state.updateOrderStatus(ord.id, 'Qabul qilindi', driver),
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: const Text("BUYURTMANI QABUL QILISH", style: TextStyle(fontWeight: FontWeight.bold)),
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
}

// ==================== 3. OPERATOR MARKAZI (TO'LIQ DISPETCHER PANELI) ====================
class OperatorView extends StatefulWidget {
  final AppState state;
  const OperatorView({super.key, required this.state});
  @override
  State<OperatorView> createState() => _OperatorViewState();
}

class _OperatorViewState extends State<OperatorView> {
  final TextEditingController _phoneCtrl = TextEditingController(text: "+998 90 ");
  final TextEditingController _fromCtrl = TextEditingController(text: "Markaziy bozor");
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _kmCtrl = TextEditingController(text: "3.5");
  String _tariff = "Standart";

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Qo'lda yangi buyurtma kiritish", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: "Mijoz telefoni", isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _tariff,
                          decoration: const InputDecoration(labelText: "Tarif", isDense: true, border: OutlineInputBorder()),
                          items: ["Standart", "Komfort", "Dostavka"]
                              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (v) => setState(() => _tariff = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fromCtrl,
                          decoration: const InputDecoration(labelText: "Qayerdan oladi", isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _toCtrl,
                          decoration: const InputDecoration(labelText: "Qayerga boradi", isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: kTaxiYellow, foregroundColor: Colors.black),
                      onPressed: () {
                        if (_toCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Borish manzilini yozing!"), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        FocusManager.instance.primaryFocus?.unfocus();
                        double km = double.tryParse(_kmCtrl.text) ?? 3.0;
                        int price = ((widget.state.stdBase + km * widget.state.stdPerKm) / 500).round() * 500;

                        widget.state.createOrder(
                          OrderModel(
                            id: "OP-${Random().nextInt(900) + 100}",
                            clientPhone: _phoneCtrl.text.trim(),
                            fromAddress: _fromCtrl.text.trim(),
                            toAddress: _toCtrl.text.trim(),
                            fromPoint: const Point(latitude: 55.7512, longitude: 37.6184),
                            toPoint: const Point(latitude: 55.7612, longitude: 37.6284),
                            tariff: _tariff,
                            distanceKm: km,
                            price: price,
                            createdAt: DateTime.now(),
                          ),
                        );
                        _toCtrl.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Buyurtma haydovchilarga yuborildi!"), backgroundColor: kBekGreen),
                        );
                      },
                      icon: const Icon(Icons.send),
                      label: const Text("HAYDOVCHILARGA YUBORISH", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text("Barcha buyurtmalar tarixi (${widget.state.orders.length}):", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Expanded(
            child: widget.state.orders.isEmpty
                ? const Center(child: Text("Hozircha buyurtmalar yo'q", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: widget.state.orders.length,
                    itemBuilder: (ctx, i) {
                      final o = widget.state.orders[i];
                      return Card(
                        child: ListTile(
                          dense: true,
                          title: Text("${o.id} • ${o.toAddress} (${o.price} so'm)", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Holat: ${o.status} • Haydovchi: ${o.driverName ?? 'Biriktirilmagan'}"),
                          trailing: o.status == 'Kutilmoqda'
                              ? IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () => widget.state.cancelOrder(o.id),
                                )
                              : null,
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

// ==================== 4. SUPER-ADMIN PANELI (TO'LIQ BOSHQARUV) ====================
class AdminView extends StatefulWidget {
  final AppState state;
  const AdminView({super.key, required this.state});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  late TextEditingController _stdBaseCtrl;
  late TextEditingController _stdKmCtrl;
  late TextEditingController _comfBaseCtrl;
  late TextEditingController _comfKmCtrl;
  late TextEditingController _commCtrl;

  @override
  void initState() {
    super.initState();
    _stdBaseCtrl = TextEditingController(text: widget.state.stdBase.toString());
    _stdKmCtrl = TextEditingController(text: widget.state.stdPerKm.toString());
    _comfBaseCtrl = TextEditingController(text: widget.state.comfBase.toString());
    _comfKmCtrl = TextEditingController(text: widget.state.comfPerKm.toString());
    _commCtrl = TextEditingController(text: widget.state.commissionPercent.toString());
  }

  void _showAddDriverDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: "+998 90 ");
    final carCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: "100000");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yangi haydovchi qo'shish", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "F.I.Sh")),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefon raqami")),
              TextField(controller: carCtrl, decoration: const InputDecoration(labelText: "Mashina rusumi va rangi")),
              TextField(controller: numCtrl, decoration: const InputDecoration(labelText: "Davlat raqami")),
              TextField(controller: balCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Boshlang'ich balans")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBekGreen, foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              widget.state.addDriver(
                nameCtrl.text.trim(),
                phoneCtrl.text.trim(),
                carCtrl.text.trim().isEmpty ? "Oq Cobalt" : carCtrl.text.trim(),
                numCtrl.text.trim().isEmpty ? "01 A 000 AA" : numCtrl.text.trim(),
                "Standart",
                int.tryParse(balCtrl.text) ?? 100000,
              );
              Navigator.pop(ctx);
            },
            child: const Text("QO'SHISH"),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Tarif va Komissiya sozlamalari", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _stdBaseCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Standart (min)", isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _stdKmCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Standart (1 km)", isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _comfBaseCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Komfort (min)", isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _comfKmCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Komfort (1 km)", isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _commCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Xizmat komissiyasi (%)", isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: kBekGreen, foregroundColor: Colors.white),
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        widget.state.saveTariffs(
                          sB: int.tryParse(_stdBaseCtrl.text) ?? 4000,
                          sK: int.tryParse(_stdKmCtrl.text) ?? 2000,
                          cB: int.tryParse(_comfBaseCtrl.text) ?? 5000,
                          cK: int.tryParse(_comfKmCtrl.text) ?? 3000,
                          dB: widget.state.delivBase,
                          dK: widget.state.delivPerKm,
                          comm: double.tryParse(_commCtrl.text) ?? 10.0,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Yangi tariflar saqlandi!"), backgroundColor: kBekGreen),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text("TARIFLARNI SAQLASH", style: TextStyle(fontWeight: FontWeight.bold)),
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
              Text("Haydovchilar bazasi (${widget.state.drivers.length}):", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kDarkBg, foregroundColor: kTaxiYellow),
                onPressed: _showAddDriverDialog,
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text("Qo'shish"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.state.drivers.map((d) => Card(
                child: ListTile(
                  title: Text("${d.name} (${d.carNumber})", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${d.carModel} • Balans: ${d.balance} so'm"),
                  trailing: TextButton.icon(
                    onPressed: () => widget.state.topUpDriverBalance(d.id, 50000),
                    icon: const Icon(Icons.add_circle, color: kBekGreen, size: 18),
                    label: const Text("+50 ming", style: TextStyle(color: kBekGreen, fontWeight: FontWeight.bold)),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
