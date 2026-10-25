// ============================================================================
// ELEGANT TAXI - CLOUD PRO (1-QISM)
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.initializeApp();
  runApp(const ElegantTaxiApp());
}

const Color kPrimaryGreen = Color(0xFF22A038);
const Color kAccentYellow = Color(0xFFFFCC00);
const Color kDarkBg = Color(0xFF14171F);
const Color kDarkCard = Color(0xFF1E222D);
const String kFirebaseDbUrl = "https://elegant-taxi-b4e46-default-rtdb.firebaseio.com";

class AppStrings {
  static Map<String, Map<String, String>> data = {
    "O'zbek": {
      "client_role": "Mijoz (Taksi chaqirish)",
      "driver_role": "Haydovchi terminali",
      "operator_role": "Dispetcher (Operator)",
      "admin_role": "Super-Admin",
      "from_hint": "Qayerdan chiqasiz?",
      "to_hint": "Qayerga ketyapsiz?",
      "order_btn": "Buyurtma berish",
      "taxi": "Taksi",
      "delivery": "Dostavka",
      "standard": "Standart",
      "comfort": "Komfort",
      "wishes": "Istaklar",
      "bonuses": "Bonuslar",
      "history": "Buyurtmalar tarixi",
      "favorites": "Sevimli manzillar",
      "about_company": "Kompaniya haqida",
      "news": "Yangiliklar va aksiyalar",
      "feedback": "Qayta aloqa",
      "settings": "Sozlamalar",
      "about_app": "Ilova haqida",
      "change_lang": "Tilni almashtirish",
      "theme_mode": "Interfeys mavzusi",
      "dark_theme": "Tungi",
      "light_theme": "Kunduzgi",
      "geolocation": "Geolokatsiya",
      "push_notif": "Push bildirishnoma",
      "locating": "Manzil aniqlanmoqda...",
      "search_street": "Ko'cha, uy yoki mo'ljalni yozing...",
      "logout": "Akkauntdan chiqish",
    },
    "Русский": {
      "client_role": "Клиент (Вызов такси)",
      "driver_role": "Терминал водителя",
      "operator_role": "Диспетчер (Оператор)",
      "admin_role": "Супер-Админ",
      "from_hint": "Откуда поедете?",
      "to_hint": "Куда поедете?",
      "order_btn": "Заказать",
      "taxi": "Такси",
      "delivery": "Доставка",
      "standard": "Стандарт",
      "comfort": "Комфорт",
      "wishes": "Пожелания",
      "bonuses": "Бонусы",
      "history": "История заказов",
      "favorites": "Любимые адреса",
      "about_company": "О компании",
      "news": "Новости и акции",
      "feedback": "Обратная связь",
      "settings": "Настройки",
      "about_app": "О приложении",
      "change_lang": "Сменить язык",
      "theme_mode": "Тема интерфейса",
      "dark_theme": "Ночная",
      "light_theme": "Дневная",
      "geolocation": "Геолокация",
      "push_notif": "Push-уведомления",
      "locating": "Определение адреса...",
      "search_street": "Введите улицу, дом или объект...",
      "logout": "Выйти из аккаунта",
    },
    "English": {
      "client_role": "Client (Book a Ride)",
      "driver_role": "Driver Terminal",
      "operator_role": "Dispatcher (Operator)",
      "admin_role": "Super-Admin",
      "from_hint": "Where from?",
      "to_hint": "Where to?",
      "order_btn": "Order Ride",
      "taxi": "Taxi",
      "delivery": "Delivery",
      "standard": "Standard",
      "comfort": "Comfort",
      "wishes": "Preferences",
      "bonuses": "Bonuses",
      "history": "Order History",
      "favorites": "Favorite Places",
      "about_company": "About Company",
      "news": "News & Promotions",
      "feedback": "Contact & Support",
      "settings": "Settings",
      "about_app": "About App",
      "change_lang": "Language",
      "theme_mode": "Interface Theme",
      "dark_theme": "Dark",
      "light_theme": "Light",
      "geolocation": "Geolocation",
      "push_notif": "Push Notifications",
      "locating": "Detecting location...",
      "search_street": "Type street, building or place...",
      "logout": "Log out",
    },
  };

  static String tr(String key) {
    final lang = appState.currentLanguage;
    return data[lang]?[key] ?? data["O'zbek"]![key] ?? key;
  }
}

class AddressSuggestion {
  final String title;
  final String subtitle;
  final Point point;
  final double distanceKm;
  AddressSuggestion({
    required this.title,
    required this.subtitle,
    required this.point,
    this.distanceKm = 0.0,
  });
}

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
  final List<String> wishes;
  String status;
  String? driverId;
  String? driverName;
  String? driverCar;
  String? driverPhone;
  final DateTime createdAt;
  int updatedAtMs;

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
    this.wishes = const [],
    this.status = 'Kutilmoqda',
    this.driverId,
    this.driverName,
    this.driverCar,
    this.driverPhone,
    required this.createdAt,
    int? updatedAtMs,
  }) : updatedAtMs = updatedAtMs ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientPhone': clientPhone,
        'fromAddress': fromAddress,
        'toAddress': toAddress,
        'fromLat': fromPoint.latitude,
        'fromLon': fromPoint.longitude,
        'toLat': toPoint.latitude,
        'toLon': toPoint.longitude,
        'tariff': tariff,
        'distanceKm': distanceKm,
        'price': price,
        'wishes': wishes,
        'status': status,
        'driverId': driverId,
        'driverName': driverName,
        'driverCar': driverCar,
        'driverPhone': driverPhone,
        'createdAt': createdAt.toIso8601String(),
        'updatedAtMs': updatedAtMs,
      };

  factory OrderModel.fromJson(Map<String, dynamic> j) => OrderModel(
        id: j['id']?.toString() ?? 'ORD-100',
        clientPhone: j['clientPhone']?.toString() ?? '',
        fromAddress: j['fromAddress']?.toString() ?? '',
        toAddress: j['toAddress']?.toString() ?? '',
        fromPoint: Point(
          latitude: (j['fromLat'] ?? 41.3111).toDouble(),
          longitude: (j['fromLon'] ?? 69.2797).toDouble(),
        ),
        toPoint: Point(
          latitude: (j['toLat'] ?? 41.3200).toDouble(),
          longitude: (j['toLon'] ?? 69.2900).toDouble(),
        ),
        tariff: j['tariff']?.toString() ?? 'Standart',
        distanceKm: (j['distanceKm'] ?? 1.5).toDouble(),
        price: (j['price'] ?? 4000).toInt(),
        wishes: j['wishes'] is List ? List<String>.from(j['wishes']) : [],
        status: j['status']?.toString() ?? 'Kutilmoqda',
        driverId: j['driverId']?.toString(),
        driverName: j['driverName']?.toString(),
        driverCar: j['driverCar']?.toString(),
        driverPhone: j['driverPhone']?.toString(),
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAtMs: (j['updatedAtMs'] ?? 0).toInt(),
      );
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
  Point? location;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.carModel,
    required this.carNumber,
    this.tariffType = 'Standart',
    this.trips = 0,
    this.balance = 100000,
    this.isOnline = true,
    this.location,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'carModel': carModel,
        'carNumber': carNumber,
        'tariffType': tariffType,
        'trips': trips,
        'balance': balance,
        'isOnline': isOnline,
        'lat': location?.latitude ?? 41.3111,
        'lon': location?.longitude ?? 69.2797,
      };

  factory DriverModel.fromJson(Map<String, dynamic> j) => DriverModel(
        id: j['id']?.toString() ?? 'D1',
        name: j['name']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
        carModel: j['carModel']?.toString() ?? '',
        carNumber: j['carNumber']?.toString() ?? '',
        tariffType: j['tariffType']?.toString() ?? 'Standart',
        trips: (j['trips'] ?? 0).toInt(),
        balance: (j['balance'] ?? 0).toInt(),
        isOnline: j['isOnline'] ?? true,
        location: Point(
          latitude: (j['lat'] ?? 41.3111).toDouble(),
          longitude: (j['lon'] ?? 69.2797).toDouble(),
        ),
      );
}

class FavoritePlace {
  final String title;
  final String address;
  final Point point;

  FavoritePlace({required this.title, required this.address, required this.point});

  Map<String, dynamic> toJson() => {
        'title': title,
        'address': address,
        'lat': point.latitude,
        'lon': point.longitude,
      };

  factory FavoritePlace.fromJson(Map<String, dynamic> j) => FavoritePlace(
        title: j['title']?.toString() ?? 'Manzil',
        address: j['address']?.toString() ?? '',
        point: Point(
          latitude: (j['lat'] ?? 41.3111).toDouble(),
          longitude: (j['lon'] ?? 69.2797).toDouble(),
        ),
      );
}

class AppState extends ChangeNotifier {
  static const MethodChannel _nativeChannel = MethodChannel('com.example.elegant_taxi/native');
  final HttpClient _http = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  Timer? _syncTimer;
  bool _isSyncing = false;

  int stdBase = 4000;
  int stdPerKm = 2000;
  int comfBase = 5000;
  int comfPerKm = 3000;
  int delivBase = 6000;
  int delivPerKm = 2500;
  double commissionPercent = 10.0;

  bool isAuthenticated = false;
  String userName = "";
  String userPhone = "";
  String currentCity = "Joriy hudud";
  String adminPass = "9728847";
  bool isAdminUnlocked = false;
  int clientBonus = 10000;
  bool useBonus = false;
  int activeDriverIndex = 0;
  String currentLanguage = "O'zbek";
  bool isDarkMode = true;
  bool geoEnabled = true;
  bool pushEnabled = true;
  bool isFirebaseConnected = false;

  Set<String> knownPendingOrderIds = {};
  Map<String, String> knownOrderStatuses = {};
  List<OrderModel> orders = [];
  List<FavoritePlace> favorites = [];

  List<DriverModel> drivers = [
    DriverModel(
      id: "D1",
      name: "Sardor Aliyev",
      phone: "+998 90 123 45 67",
      carModel: "Oq Chevrolet Cobalt",
      carNumber: "75 A 777 AA",
      tariffType: "Standart",
      trips: 144,
      balance: 584200,
    ),
    DriverModel(
      id: "D2",
      name: "Jasur Karimov",
      phone: "+998 90 987 65 43",
      carModel: "Qora Chevrolet Gentra",
      carNumber: "75 B 555 BB",
      tariffType: "Komfort",
      trips: 98,
      balance: 120000,
    ),
  ];

  String get cleanPhoneKey => userPhone.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> initializeApp() async {
    await loadFromStorage();
    await syncFromFirebase(isInitial: true);
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => syncFromFirebase());
  }

  Future<void> loadFromStorage() async {
    try {
      final String? raw = await _nativeChannel.invokeMethod<String>('loadData');
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(raw);
        isAuthenticated = data['isAuthenticated'] ?? false;
        userName = data['userName'] ?? "";
        userPhone = data['userPhone'] ?? "";
        stdBase = data['stdBase'] ?? 4000;
        stdPerKm = data['stdPerKm'] ?? 2000;
        comfBase = data['comfBase'] ?? 5000;
        comfPerKm = data['comfPerKm'] ?? 3000;
        delivBase = data['delivBase'] ?? 6000;
        delivPerKm = data['delivPerKm'] ?? 2500;
        commissionPercent = (data['commissionPercent'] ?? 10.0).toDouble();
        clientBonus = data['clientBonus'] ?? 10000;
        activeDriverIndex = data['activeDriverIndex'] ?? 0;
        currentLanguage = data['currentLanguage'] ?? "O'zbek";
        isDarkMode = data['isDarkMode'] ?? true;
        geoEnabled = data['geoEnabled'] ?? true;
        pushEnabled = data['pushEnabled'] ?? true;

        if (data['favorites'] is List) {
          favorites = (data['favorites'] as List).map((e) => FavoritePlace.fromJson(e)).toList();
        }
        if (data['drivers'] is List) {
          drivers = (data['drivers'] as List).map((e) => DriverModel.fromJson(e)).toList();
        }
        if (data['orders'] is List) {
          orders = (data['orders'] as List).map((e) => OrderModel.fromJson(e)).toList();
        }
        if (activeDriverIndex >= drivers.length) activeDriverIndex = 0;
        for (final o in orders) {
          knownOrderStatuses[o.id] = o.status;
          if (o.status == 'Kutilmoqda') knownPendingOrderIds.add(o.id);
        }
      }
    } catch (_) {}
  }

  Future<void> saveToStorage() async {
    try {
      final Map<String, dynamic> localData = {
        'isAuthenticated': isAuthenticated,
        'userName': userName,
        'userPhone': userPhone,
        'stdBase': stdBase,
        'stdPerKm': stdPerKm,
        'comfBase': comfBase,
        'comfPerKm': comfPerKm,
        'delivBase': delivBase,
        'delivPerKm': delivPerKm,
        'commissionPercent': commissionPercent,
        'clientBonus': clientBonus,
        'activeDriverIndex': activeDriverIndex,
        'currentLanguage': currentLanguage,
        'isDarkMode': isDarkMode,
        'geoEnabled': geoEnabled,
        'pushEnabled': pushEnabled,
        'favorites': favorites.map((f) => f.toJson()).toList(),
        'drivers': drivers.map((d) => d.toJson()).toList(),
        'orders': orders.map((o) => o.toJson()).toList(),
      };
      await _nativeChannel.invokeMethod('saveData', {'data': jsonEncode(localData)});
    } catch (_) {}
  }

  Future<void> _putJson(String path, Map<String, dynamic> payload) async {
    final Uri uri = Uri.parse("$kFirebaseDbUrl/$path.json");
    final HttpClientRequest req = await _http.putUrl(uri);
    req.headers.set('Content-Type', 'application/json; charset=utf-8');
    req.add(utf8.encode(jsonEncode(payload)));
    final HttpClientResponse res = await req.close();
    await res.drain();
  }

  // Har bir buyurtmani alohida tugunga yozish (Ikkita telefon bir-birini ustidan bosib yubormasligi uchun)
  Future<void> pushSingleOrderToFirebase(OrderModel order) async {
    try {
      await _putJson("elegant_cloud/orders/${order.id}", order.toJson());
      isFirebaseConnected = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> pushDriversAndConfigToFirebase() async {
    try {
      final Map<String, dynamic> drvMap = {for (var d in drivers) d.id: d.toJson()};
      await _putJson("elegant_cloud/drivers", drvMap);
      await _putJson("elegant_cloud/config", {
        'stdBase': stdBase,
        'stdPerKm': stdPerKm,
        'comfBase': comfBase,
        'comfPerKm': comfPerKm,
        'delivBase': delivBase,
        'delivPerKm': delivPerKm,
        'commissionPercent': commissionPercent,
      });
      isFirebaseConnected = true;
      notifyListeners();
    } catch (_) {}
  }

  // Foydalanuvchi profilini telefon raqami bo'yicha Firebase'da saqlash va tiklash
  Future<void> syncUserProfileWithCloud({bool pullFirst = false}) async {
    final key = cleanPhoneKey;
    if (key.length < 7) return;
    try {
      if (pullFirst) {
        final Uri uri = Uri.parse("$kFirebaseDbUrl/elegant_cloud/users/$key.json");
        final HttpClientRequest req = await _http.getUrl(uri);
        final HttpClientResponse res = await req.close();
        if (res.statusCode == 200) {
          final String body = await res.transform(utf8.decoder).join();
          if (body.isNotEmpty && body != "null") {
            final Map<String, dynamic> uData = jsonDecode(body);
            if ((uData['userName']?.toString() ?? '').isNotEmpty && userName.isEmpty) {
              userName = uData['userName'];
            }
            clientBonus = (uData['clientBonus'] ?? clientBonus).toInt();
            if (uData['favorites'] is List) {
              favorites = (uData['favorites'] as List).map((e) => FavoritePlace.fromJson(e)).toList();
            }
          }
        }
      }
      await _putJson("elegant_cloud/users/$key", {
        'userName': userName,
        'userPhone': userPhone,
        'clientBonus': clientBonus,
        'favorites': favorites.map((f) => f.toJson()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      await saveToStorage();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> syncFromFirebase({bool isInitial = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final Uri uri = Uri.parse("$kFirebaseDbUrl/elegant_cloud.json");
      final HttpClientRequest req = await _http.getUrl(uri);
      final HttpClientResponse res = await req.close();
      if (res.statusCode == 200) {
        final String body = await res.transform(utf8.decoder).join();
        isFirebaseConnected = true;
        if (body.isNotEmpty && body != "null") {
          final Map<String, dynamic> root = jsonDecode(body);
          bool changed = false;
          bool shouldPlaySound = false;

          if (root['config'] is Map) {
            final cfg = Map<String, dynamic>.from(root['config']);
            final int nSB = cfg['stdBase'] ?? stdBase;
            final int nSK = cfg['stdPerKm'] ?? stdPerKm;
            final int nCB = cfg['comfBase'] ?? comfBase;
            final int nCK = cfg['comfPerKm'] ?? comfPerKm;
            final double nComm = (cfg['commissionPercent'] ?? commissionPercent).toDouble();
            if (nSB != stdBase || nSK != stdPerKm || nCB != comfBase || nCK != comfPerKm || nComm != commissionPercent) {
              stdBase = nSB;
              stdPerKm = nSK;
              comfBase = nCB;
              comfPerKm = nCK;
              commissionPercent = nComm;
              changed = true;
            }
          }

          if (root['drivers'] is Map) {
            final Map<String, dynamic> dMap = Map<String, dynamic>.from(root['drivers']);
            final List<DriverModel> cloudDrivers = dMap.values
                .whereType<Map>()
                .map((e) => DriverModel.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            if (cloudDrivers.isNotEmpty) {
              final oldJson = jsonEncode(drivers.map((d) => d.toJson()).toList());
              final newJson = jsonEncode(cloudDrivers.map((d) => d.toJson()).toList());
              if (oldJson != newJson) {
                drivers = cloudDrivers;
                if (activeDriverIndex >= drivers.length) activeDriverIndex = 0;
                changed = true;
              }
            }
          }

          if (root['orders'] is Map) {
            final Map<String, dynamic> oMap = Map<String, dynamic>.from(root['orders']);
            final List<OrderModel> cloudOrders = oMap.values
                .whereType<Map>()
                .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            cloudOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            final oldJson = jsonEncode(orders.map((o) => o.toJson()).toList());
            final newJson = jsonEncode(cloudOrders.map((o) => o.toJson()).toList());
            if (oldJson != newJson) {
              for (final co in cloudOrders) {
                final prevStatus = knownOrderStatuses[co.id];
                if (prevStatus == null && co.status == 'Kutilmoqda' && !isInitial) {
                  shouldPlaySound = true;
                } else if (prevStatus != null && prevStatus != co.status && !isInitial) {
                  shouldPlaySound = true;
                }
                knownOrderStatuses[co.id] = co.status;
              }
              orders = cloudOrders;
              changed = true;
            }
          }

          if (shouldPlaySound && pushEnabled) {
            playNotificationSound();
          }
          if (changed) {
            await saveToStorage();
            notifyListeners();
          }
        } else if (isInitial) {
          await pushDriversAndConfigToFirebase();
        }
      }
    } catch (_) {
      isFirebaseConnected = false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> playNotificationSound() async {
    try {
      HapticFeedback.heavyImpact();
      await _nativeChannel.invokeMethod('playSound');
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> completeLogin(String name, String phone) async {
    userName = name.trim();
    userPhone = phone.trim();
    isAuthenticated = true;
    await syncUserProfileWithCloud(pullFirst: true);
    await saveToStorage();
    notifyListeners();
  }

  Future<void> logoutUser() async {
    await syncUserProfileWithCloud(pullFirst: false);
    isAuthenticated = false;
    isAdminUnlocked = false;
    await saveToStorage();
    notifyListeners();
  }

  void createOrder(OrderModel order) {
    orders.removeWhere((o) => o.id == order.id);
    orders.insert(0, order);
    knownOrderStatuses[order.id] = order.status;
    if (useBonus && clientBonus > 0) {
      int used = min(clientBonus, 3000);
      clientBonus -= used;
      syncUserProfileWithCloud();
    }
    saveToStorage();
    pushSingleOrderToFirebase(order);
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
      orders[idx].updatedAtMs = DateTime.now().millisecondsSinceEpoch;
      knownOrderStatuses[orderId] = newStatus;

      if (newStatus == 'Yakunlandi') {
        int comm = ((orders[idx].price * commissionPercent) / 100).round();
        driver.balance -= comm;
        driver.trips += 1;
        if (orders[idx].clientPhone == userPhone) {
          clientBonus += 500;
          syncUserProfileWithCloud();
        }
        pushDriversAndConfigToFirebase();
      }
      saveToStorage();
      pushSingleOrderToFirebase(orders[idx]);
      playNotificationSound();
      notifyListeners();
    }
  }

  void cancelOrder(String orderId) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      orders[idx].status = 'Bekor qilindi';
      orders[idx].updatedAtMs = DateTime.now().millisecondsSinceEpoch;
      knownOrderStatuses[orderId] = 'Bekor qilindi';
      saveToStorage();
      pushSingleOrderToFirebase(orders[idx]);
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
    saveToStorage();
    pushDriversAndConfigToFirebase();
    playNotificationSound();
    notifyListeners();
  }

  void addDriver(String name, String phone, String car, String num, String tariff, int bal) {
    drivers.add(DriverModel(
      id: "D${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      phone: phone,
      carModel: car,
      carNumber: num,
      tariffType: tariff,
      trips: 0,
      balance: bal,
    ));
    activeDriverIndex = drivers.length - 1;
    saveToStorage();
    pushDriversAndConfigToFirebase();
    notifyListeners();
  }

  void deleteDriver(String driverId) {
    if (drivers.length <= 1) return;
    drivers.removeWhere((d) => d.id == driverId);
    if (activeDriverIndex >= drivers.length) activeDriverIndex = 0;
    saveToStorage();
    pushDriversAndConfigToFirebase();
    notifyListeners();
  }

  void topUpDriverBalance(String driverId, int amount) {
    final idx = drivers.indexWhere((d) => d.id == driverId);
    if (idx != -1) {
      drivers[idx].balance += amount;
      saveToStorage();
      pushDriversAndConfigToFirebase();
      notifyListeners();
    }
  }

  void addFavorite(String title, String address, Point pt) {
    favorites.insert(0, FavoritePlace(title: title, address: address, point: pt));
    saveToStorage();
    syncUserProfileWithCloud();
    notifyListeners();
  }

  void removeFavorite(int index) {
    favorites.removeAt(index);
    saveToStorage();
    syncUserProfileWithCloud();
    notifyListeners();
  }

  void updateProfile(String newName, String newPhone) {
    userName = newName;
    userPhone = newPhone;
    saveToStorage();
    syncUserProfileWithCloud();
    notifyListeners();
  }
}

final AppState appState = AppState();

class ElegantTaxiApp extends StatelessWidget {
  const ElegantTaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final bool dark = appState.isDarkMode;
        return MaterialApp(
          title: 'Elegant Taxi',
          debugShowCheckedModeBanner: false,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: kPrimaryGreen,
            scaffoldBackgroundColor: const Color(0xFFF5F6F8),
            cardColor: Colors.white,
            fontFamily: 'Roboto',
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: kPrimaryGreen,
            scaffoldBackgroundColor: kDarkBg,
            cardColor: kDarkCard,
            fontFamily: 'Roboto',
            useMaterial3: true,
          ),
          home: appState.isAuthenticated ? const RoleContainerScreen() : const PhoneAuthScreen(),
        );
      },
    );
  }
}

// ============================================================================
// TELEFON RAQAMI VA SMS KOD ORQALI KIRISH EKRANI (Bulutli sinxronizatsiya bilan)
// ============================================================================
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();

  String _countryCode = "+998";
  bool _codeSent = false;
  String _generatedOtp = "";
  String? _errorMsg;
  bool _isLoading = false;

  void _sendSmsCode() {
    final name = _nameCtrl.text.trim();
    final rawPhone = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (name.isEmpty) {
      setState(() => _errorMsg = "Iltimos, ismingizni kiriting");
      return;
    }
    if (rawPhone.length < 7) {
      setState(() => _errorMsg = "Telefon raqamni to'liq kiriting");
      return;
    }

    final code = (Random().nextInt(9000) + 1000).toString();
    appState.playNotificationSound();
    setState(() {
      _generatedOtp = code;
      _codeSent = true;
      _errorMsg = null;
      _otpCtrl.text = code;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kPrimaryGreen,
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            const Icon(Icons.sms, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Elegant Taxi SMS kodi: $code",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyAndLogin() async {
    if (_otpCtrl.text.trim() != _generatedOtp) {
      HapticFeedback.vibrate();
      setState(() => _errorMsg = "Tasdiqlash kodi noto'g'ri!");
      return;
    }
    setState(() => _isLoading = true);
    final fullPhone = "$_countryCode ${_phoneCtrl.text.trim()}";
    await appState.completeLogin(_nameCtrl.text.trim(), fullPhone);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = appState.isDarkMode;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: kPrimaryGreen,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: kPrimaryGreen.withOpacity(0.35), blurRadius: 16)],
                  ),
                  child: const Icon(Icons.local_taxi, color: Colors.white, size: 46),
                ),
                const SizedBox(height: 16),
                const Text("Elegant Taxi", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  _codeSent
                      ? "SMS orqali yuborilgan 4 xonali kodni kiriting"
                      : "Telefon raqamingiz orqali tizimga kiring.\nBarcha bonus va buyurtmalaringiz saqlanadi.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: dark ? kDarkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_codeSent) ...[
                        TextField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: "Ismingiz",
                            prefixIcon: const Icon(Icons.person_outline, color: kPrimaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade600),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _countryCode,
                                  items: const [
                                    DropdownMenuItem(value: "+998", child: Text("🇺🇿 +998")),
                                    DropdownMenuItem(value: "+7", child: Text("🇷🇺 +7")),
                                  ],
                                  onChanged: (v) => setState(() => _countryCode = v!),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: "Telefon raqam",
                                  hintText: _countryCode == "+998" ? "90 123 45 67" : "900 123 45 67",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kPrimaryGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user, color: kPrimaryGreen),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Raqam: $_countryCode ${_phoneCtrl.text}\nTasdiqlash kodi: $_generatedOtp",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _codeSent = false),
                                child: const Text("O'zgartirish"),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _otpCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                          decoration: InputDecoration(
                            labelText: "SMS Tasdiqlash kodi",
                            counterText: "",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 10),
                        Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isLoading ? null : (_codeSent ? _verifyAndLogin : _sendSmsCode),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  _codeSent ? "TASDIQLASH VA KIRISH" : "SMS KOD OLISH",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ASOSIY KONTEYNER VA MENYU (Kunduzgi/Tungi ranglar 100% to'g'rilangan)
// ============================================================================
class RoleContainerScreen extends StatefulWidget {
  const RoleContainerScreen({super.key});
  @override
  State<RoleContainerScreen> createState() => _RoleContainerScreenState();
}

class _RoleContainerScreenState extends State<RoleContainerScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<_ClientMapScreenState> _mapScreenKey = GlobalKey<_ClientMapScreenState>();
  int _selectedRole = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      appState.syncFromFirebase();
    }
  }

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
                Icon(Icons.lock_outline, color: kPrimaryGreen),
                SizedBox(width: 8),
                Text("Super-Admin", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: TextField(
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
            actions: [
              TextButton(
                onPressed: () {
                  _hideKeyboard();
                  Navigator.pop(ctx);
                },
                child: const Text("Bekor qilish", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
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

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: appState.userName);
    final phoneCtrl = TextEditingController(text: appState.userPhone);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Profil ma'lumotlari"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ismingiz")),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefon raqamingiz")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                appState.updateProfile(nameCtrl.text.trim(), phoneCtrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text("Saqlash"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final int pendingCount = appState.orders.where((o) => o.status == 'Kutilmoqda').length;
        final bool dark = appState.isDarkMode;
        final Color textColor = dark ? Colors.white : Colors.black87;
        final Color subIconColor = dark ? Colors.white70 : Colors.black54;

        return GestureDetector(
          onTap: _hideKeyboard,
          child: Scaffold(
            key: _scaffoldKey,
            resizeToAvoidBottomInset: true,
            appBar: _selectedRole == 0
                ? null
                : AppBar(
                    backgroundColor: kDarkBg,
                    iconTheme: const IconThemeData(color: kAccentYellow),
                    title: Row(
                      children: [
                        Text(
                          _selectedRole == 1
                              ? "HAYDOVCHI TERMINALI"
                              : _selectedRole == 2
                                  ? "OPERATOR MARKAZI"
                                  : "SUPER-ADMIN",
                          style: const TextStyle(color: kAccentYellow, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.cloud_done,
                          size: 16,
                          color: appState.isFirebaseConnected ? kPrimaryGreen : Colors.grey,
                        ),
                      ],
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
              backgroundColor: dark ? kDarkBg : Colors.white,
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: dark ? kDarkCard : kPrimaryGreen.withOpacity(0.1),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: kPrimaryGreen.withOpacity(0.2),
                            child: const Icon(Icons.person_outline, color: kPrimaryGreen, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appState.userName,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textColor),
                                ),
                                Text(
                                  appState.userPhone,
                                  style: TextStyle(fontSize: 12, color: subIconColor),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kPrimaryGreen,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.card_giftcard, color: Colors.white, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${appState.clientBonus}",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_note, color: kPrimaryGreen),
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditProfileDialog();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.map_outlined, color: kPrimaryGreen),
                            title: Text(AppStrings.tr("client_role"), style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                            selected: _selectedRole == 0,
                            onTap: () => _selectRoleFromDrawer(0),
                          ),
                          ListTile(
                            leading: const Icon(Icons.local_taxi_outlined, color: Colors.green),
                            title: Text(AppStrings.tr("driver_role"), style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
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
                            leading: const Icon(Icons.headset_mic_outlined, color: Colors.orange),
                            title: Text(AppStrings.tr("operator_role"), style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                            selected: _selectedRole == 2,
                            onTap: () => _selectRoleFromDrawer(2),
                          ),
                          ListTile(
                            leading: const Icon(Icons.admin_panel_settings_outlined, color: Colors.redAccent),
                            title: Text(AppStrings.tr("admin_role"), style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                            trailing: Icon(
                              appState.isAdminUnlocked ? Icons.lock_open : Icons.lock_outline,
                              size: 18,
                              color: subIconColor,
                            ),
                            selected: _selectedRole == 3,
                            onTap: () => _selectRoleFromDrawer(3),
                          ),
                          const Divider(),
                          ListTile(
                            leading: Icon(Icons.access_time, color: subIconColor),
                            title: Text(AppStrings.tr("history"), style: TextStyle(color: textColor)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.location_on_outlined, color: subIconColor),
                            title: Text(AppStrings.tr("favorites"), style: TextStyle(color: textColor)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FavoritePlacesScreen(
                                    onSelectFavorite: (fav) {
                                      _switchRoleDirect(0);
                                      _mapScreenKey.currentState?.selectFavoriteDestination(fav);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.info_outline, color: subIconColor),
                            title: Text(AppStrings.tr("about_company"), style: TextStyle(color: textColor)),
                            subtitle: const Text("Elegant Taxi", style: TextStyle(fontSize: 12, color: kPrimaryGreen)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutCompanyScreen()));
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.campaign_outlined, color: subIconColor),
                            title: Text(AppStrings.tr("news"), style: TextStyle(color: textColor)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsPromosScreen()));
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.chat_outlined, color: subIconColor),
                            title: Text(AppStrings.tr("feedback"), style: TextStyle(color: textColor)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackSupportScreen()));
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.settings_outlined, color: subIconColor),
                            title: Text(AppStrings.tr("settings"), style: TextStyle(color: textColor)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const FullSettingsScreen()));
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.logout, color: Colors.redAccent),
                            title: Text(AppStrings.tr("logout"), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                            onTap: () {
                              Navigator.pop(context);
                              appState.logoutUser();
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kPrimaryGreen.withOpacity(0.9), kPrimaryGreen.withOpacity(0.5)],
                        ),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: kAccentYellow,
                            child: Icon(Icons.local_taxi, color: Colors.black, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Elegant Taxi",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              appState.isFirebaseConnected ? "Online" : "Local",
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: IndexedStack(
              index: _selectedRole,
              children: [
                ClientMapScreen(
                  key: _mapScreenKey,
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

class FullSettingsScreen extends StatelessWidget {
  const FullSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final bool dark = appState.isDarkMode;
        return Scaffold(
          appBar: AppBar(
            title: Text(AppStrings.tr("settings"), style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          body: ListView(
            children: [
              ListTile(
                title: Text(AppStrings.tr("change_lang"), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(appState.currentLanguage, style: const TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.chevron_right, color: kPrimaryGreen),
                onTap: () => _openLanguageSelector(context),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(AppStrings.tr("theme_mode"), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  dark ? AppStrings.tr("dark_theme") : AppStrings.tr("light_theme"),
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: const Icon(Icons.chevron_right, color: kPrimaryGreen),
                onTap: () => _openThemeSelector(context),
              ),
              const Divider(height: 1),
              SwitchListTile(
                activeColor: kPrimaryGreen,
                title: Text(AppStrings.tr("geolocation"), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  "Geolokatsiyani o'chirib qo'yish manzilni aniqlashni qiyinlashtiradi",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: appState.geoEnabled,
                onChanged: (val) {
                  appState.geoEnabled = val;
                  appState.saveToStorage();
                  appState.notifyListeners();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                activeColor: kPrimaryGreen,
                title: Text(AppStrings.tr("push_notif"), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  "Buyurtma holatidagi o'zgarishlar haqida ovozli bildirishnomalar",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: appState.pushEnabled,
                onChanged: (val) {
                  appState.pushEnabled = val;
                  appState.saveToStorage();
                  appState.notifyListeners();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openLanguageSelector(BuildContext context) {
    final langs = [
      {"code": "O'zbek", "label": "O'zbek (Tizim tili)"},
      {"code": "Русский", "label": "Русский"},
      {"code": "English", "label": "English"},
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Tilni tanlash", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const Divider(height: 1),
            ...langs.map(
              (l) => ListTile(
                title: Text(
                  l["label"]!,
                  style: TextStyle(
                    color: appState.currentLanguage == l["code"] ? kPrimaryGreen : null,
                    fontWeight: appState.currentLanguage == l["code"] ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: appState.currentLanguage == l["code"] ? const Icon(Icons.check, color: kPrimaryGreen) : null,
                onTap: () {
                  appState.currentLanguage = l["code"]!;
                  appState.saveToStorage();
                  appState.notifyListeners();
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openThemeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Interfeys mavzusi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.dark_mode, color: kPrimaryGreen),
              title: const Text("Tungi (Dark)"),
              trailing: appState.isDarkMode ? const Icon(Icons.check, color: kPrimaryGreen) : null,
              onTap: () {
                appState.isDarkMode = true;
                appState.saveToStorage();
                appState.notifyListeners();
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode, color: Colors.orange),
              title: const Text("Kunduzgi (Light)"),
              trailing: !appState.isDarkMode ? const Icon(Icons.check, color: kPrimaryGreen) : null,
              onTap: () {
                appState.isDarkMode = false;
                appState.saveToStorage();
                appState.notifyListeners();
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(AppStrings.tr("history"))),
          body: appState.orders.isEmpty
              ? const Center(child: Text("Hozircha buyurtmalar tarixi bo'sh", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: appState.orders.length,
                  itemBuilder: (ctx, i) {
                    final o = appState.orders[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: kPrimaryGreen,
                          child: Icon(Icons.local_taxi, color: Colors.white),
                        ),
                        title: Text("${o.fromAddress} ➔ ${o.toAddress}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text("${o.tariff} • ${o.distanceKm} km • Holat: ${o.status}\nHaydovchi: ${o.driverName ?? 'Biriktirilmagan'}"),
                        isThreeLine: true,
                        trailing: Text("${o.price} so'm", style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryGreen)),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class FavoritePlacesScreen extends StatelessWidget {
  final ValueChanged<FavoritePlace> onSelectFavorite;
  const FavoritePlacesScreen({super.key, required this.onSelectFavorite});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(AppStrings.tr("favorites"))),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: kPrimaryGreen,
            foregroundColor: Colors.white,
            onPressed: () => _showAddFavoriteDialog(context),
            icon: const Icon(Icons.add_location_alt),
            label: const Text("Manzil qo'shish"),
          ),
          body: appState.favorites.isEmpty
              ? const Center(child: Text("Sevimli manzillar ro'yxati bo'sh"))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: appState.favorites.length,
                  itemBuilder: (ctx, i) {
                    final fav = appState.favorites[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.star, color: kAccentYellow),
                        title: Text(fav.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(fav.address),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => appState.removeFavorite(i),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onSelectFavorite(fav);
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showAddFavoriteDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yangi sevimli manzil"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Nomi (Masalan: Uy, Ishxona)")),
            const SizedBox(height: 8),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: "Ko'cha va mo'ljal")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                appState.addFavorite(
                  titleCtrl.text.trim(),
                  addrCtrl.text.trim().isEmpty ? titleCtrl.text.trim() : addrCtrl.text.trim(),
                  const Point(latitude: 41.3111, longitude: 69.2797),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text("Saqlash"),
          ),
        ],
      ),
    );
  }
}

class AboutCompanyScreen extends StatelessWidget {
  const AboutCompanyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr("about_company"))),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: kPrimaryGreen, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.local_taxi, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Elegant Taxi", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text("Tezkor va ishonchli taksi xizmati", style: TextStyle(color: kPrimaryGreen)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Elegant Taxi — 24/7 rejimida mijozlarga sifatli, xavfsiz va hamyonbop transport hamda yetkazib berish xizmatlarini ko'rsatuvchi zamonaviy onlayn platformadir.",
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class NewsPromosScreen extends StatelessWidget {
  const NewsPromosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr("news"))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.card_giftcard, color: kPrimaryGreen),
                      SizedBox(width: 8),
                      Text("10 000 so'm Ro'yxatdan o'tish bonusi!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text("Har bir yangi foydalanuvchi uchun 10 000 so'm bonus taqdim etiladi va har bir safardan keshbek yig'iladi."),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FeedbackSupportScreen extends StatefulWidget {
  const FeedbackSupportScreen({super.key});
  @override
  State<FeedbackSupportScreen> createState() => _FeedbackSupportScreenState();
}

class _FeedbackSupportScreenState extends State<FeedbackSupportScreen> {
  final TextEditingController _msgCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr("feedback"))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: kPrimaryGreen, child: Icon(Icons.phone, color: Colors.white)),
                title: const Text("Qo'llab-quvvatlash markazi"),
                subtitle: Text(appState.userPhone.isNotEmpty ? appState.userPhone : "+998 90 267 25 80"),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _msgCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Murojaat yoki taklifingizni yozing...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
                onPressed: () {
                  if (_msgCtrl.text.trim().isEmpty) return;
                  _msgCtrl.clear();
                  FocusManager.instance.primaryFocus?.unfocus();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Murojaatingiz qabul qilindi!"), backgroundColor: kPrimaryGreen),
                  );
                },
                icon: const Icon(Icons.send),
                label: const Text("YUBORISH", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// === 1-QISM TUGADI. SHU YERDAN PASTGA 2-QISMNI QO'SHING ===
// ============================================================================
// ELEGANT TAXI - CLOUD PRO (2-QISM: XARITA, QIDIRUV, HAYDOVCHI, OPERATOR, ADMIN)
// ============================================================================

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

  Point _fromPoint = const Point(latitude: 41.3111, longitude: 69.2797);
  Point? _destinationLocation;

  String _fromAddress = "Joylashuv aniqlanmoqda...";
  String _toAddress = "";
  double _distanceKm = 0.0;
  int _etaMinutes = 2;
  String _serviceMode = 'Taksi';
  String _selectedTariff = 'Standart';
  String? _activeOrderId;
  bool _isSearchingAddress = false;

  String _pinMode = 'from';
  bool _isDraggingMap = false;
  Point _cameraCenterPoint = const Point(latitude: 41.3111, longitude: 69.2797);
  Timer? _geocodeDebounce;

  final List<String> _selectedWishes = [];
  Uint8List? _cachedStartIcon;
  Uint8List? _cachedEndIcon;
  Uint8List? _cachedTaxiIcon;

  OrderModel? get _activeOrder {
    if (_activeOrderId != null) {
      for (final o in appState.orders) {
        if (o.id == _activeOrderId) return o;
      }
    }
    if (appState.userPhone.isNotEmpty) {
      for (final o in appState.orders) {
        if (o.clientPhone == appState.userPhone && o.status != 'Bekor qilindi') {
          final ageMinutes = DateTime.now().difference(o.createdAt).inMinutes;
          if (o.status != 'Yakunlandi' || ageMinutes < 2) {
            _activeOrderId = o.id;
            return o;
          }
        }
      }
    }
    return null;
  }

  void selectFavoriteDestination(FavoritePlace fav) async {
    setState(() {
      _destinationLocation = fav.point;
      _toAddress = fav.title;
      _pinMode = 'to';
    });
    await _updateMapObjects();
    await _buildRoute();
  }

  Future<void> _ensureIconsLoaded() async {
    _cachedStartIcon ??= await _createMarkerImage(kPrimaryGreen, "A");
    _cachedEndIcon ??= await _createMarkerImage(Colors.redAccent, "B");
    _cachedTaxiIcon ??= await _createMarkerImage(kAccentYellow, "T");
  }

  // Kirill <-> Lotin transliteratsiyasi (Har ikki alifboda ham ko'chalarni topish uchun)
  String _cyrillicToLatin(String text) {
    const map = {
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo',
      'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
      'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
      'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
      'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
      'ў': "o'", 'қ': 'q', 'ғ': "g'", 'ҳ': 'h',
    };
    final sb = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      final lower = ch.toLowerCase();
      if (map.containsKey(lower)) {
        final rep = map[lower]!;
        sb.write(ch == lower ? rep : (rep.isNotEmpty ? rep[0].toUpperCase() + rep.substring(1) : ''));
      } else {
        sb.write(ch);
      }
    }
    return sb.toString();
  }

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
        final item = res.items!.first;
        final formatted = item.toponymMetadata?.address.formattedAddress ?? "";
        if (formatted.isNotEmpty) {
          final parts = formatted.split(',').map((e) => e.trim()).toList();
          if (parts.length >= 2) {
            appState.currentCity = parts[1];
          }
        }
        if (item.name.isNotEmpty) return item.name;
      }
    } catch (_) {}
    return "Ko'cha (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})";
  }

  Future<Uint8List> _createMarkerImage(Color color, String label) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(32, 32), 28, paint);
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(32, 32), 19, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color == kAccentYellow ? Colors.black : color,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
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
    await _ensureIconsLoaded();
    if (!appState.geoEnabled) {
      await _updateMapObjects();
      return;
    }
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _updateMapObjects();
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          await _updateMapObjects();
          return;
        }
      }
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;

      final pt = Point(latitude: pos.latitude, longitude: pos.longitude);
      setState(() {
        _fromPoint = pt;
        _cameraCenterPoint = pt;
      });

      if (_mapController != null) {
        await _mapController!.moveCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: _fromPoint, zoom: 16.2)),
          animation: immediateJump ? null : const MapAnimation(type: MapAnimationType.smooth, duration: 0.8),
        );
      }

      await _updateMapObjects();
      final addr = await _reverseGeocode(pt);
      if (mounted) {
        setState(() => _fromAddress = addr);
      }
      if (_destinationLocation != null) {
        await _buildRoute();
      }
    } catch (_) {
      await _updateMapObjects();
    }
  }

  double _calculateStraightDistance(Point p1, Point p2) {
    const double R = 6371.0;
    double dLat = (p2.latitude - p1.latitude) * pi / 180.0;
    double dLon = (p2.longitude - p1.longitude) * pi / 180.0;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(p1.latitude * pi / 180.0) * cos(p2.latitude * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return max(0.2, double.parse((R * c * 1.25).toStringAsFixed(1)));
  }

  Future<void> _buildRoute({bool fitCamera = true}) async {
    if (_destinationLocation == null) return;

    try {
      var resultWithSession = YandexDriving.requestRoutes(
        points: [
          RequestPoint(point: _fromPoint, requestPointType: RequestPointType.wayPoint),
          RequestPoint(point: _destinationLocation!, requestPointType: RequestPointType.wayPoint),
        ],
        drivingOptions: const DrivingOptions(initialAzimuth: 0, routesCount: 1, avoidTolls: true),
      );

      final result = await resultWithSession.result;
      if (result.routes != null && result.routes!.isNotEmpty) {
        final route = result.routes!.first;
        if (mounted) {
          setState(() {
            _distanceKm = double.parse(((route.metadata.weight.distance.value ?? 1000.0) / 1000).toStringAsFixed(1));
            _etaMinutes = max(1, ((route.metadata.weight.time.value ?? 120.0) / 60).round());
            _mapObjects.removeWhere((el) => el.mapId.value == 'route');
            _mapObjects.add(
              PolylineMapObject(
                mapId: const MapObjectId('route'),
                polyline: Polyline(points: route.geometry),
                strokeColor: kPrimaryGreen,
                strokeWidth: 5.5,
                outlineColor: Colors.black87,
                outlineWidth: 1.2,
              ),
            );
          });
        }
      } else {
        _drawFallbackRoute();
      }
    } catch (_) {
      _drawFallbackRoute();
    }

    if (fitCamera && _mapController != null && _destinationLocation != null) {
      await _mapController!.moveCamera(
        CameraUpdate.newGeometry(
          Geometry.fromBoundingBox(
            BoundingBox(
              southWest: Point(
                latitude: min(_fromPoint.latitude, _destinationLocation!.latitude) - 0.004,
                longitude: min(_fromPoint.longitude, _destinationLocation!.longitude) - 0.004,
              ),
              northEast: Point(
                latitude: max(_fromPoint.latitude, _destinationLocation!.latitude) + 0.004,
                longitude: max(_fromPoint.longitude, _destinationLocation!.longitude) + 0.004,
              ),
            ),
          ),
        ),
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.9),
      );
    }
  }

  void _drawFallbackRoute() {
    if (_destinationLocation == null || !mounted) return;
    final dist = _calculateStraightDistance(_fromPoint, _destinationLocation!);
    setState(() {
      _distanceKm = dist;
      _etaMinutes = max(1, (dist * 2.2).round());
      _mapObjects.removeWhere((el) => el.mapId.value == 'route');
      _mapObjects.add(
        PolylineMapObject(
          mapId: const MapObjectId('route'),
          polyline: Polyline(points: [_fromPoint, _destinationLocation!]),
          strokeColor: kPrimaryGreen,
          strokeWidth: 5,
        ),
      );
    });
  }

  Future<void> _updateMapObjects() async {
    await _ensureIconsLoaded();
    if (!mounted) return;

    setState(() {
      _mapObjects.removeWhere((el) => el.mapId.value != 'route');
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('start'),
          point: _fromPoint,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(_cachedStartIcon!), scale: 1.0),
          ),
        ),
      );

      for (int i = 0; i < appState.drivers.length; i++) {
        final d = appState.drivers[i];
        final pt = Point(
          latitude: _fromPoint.latitude + 0.0018 * (i + 1),
          longitude: _fromPoint.longitude + 0.0015 * (i % 2 == 0 ? 1 : -1),
        );
        _mapObjects.add(
          PlacemarkMapObject(
            mapId: MapObjectId('taxi_${d.id}'),
            point: pt,
            icon: PlacemarkIcon.single(
              PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(_cachedTaxiIcon!), scale: 0.9),
            ),
          ),
        );
      }

      if (_destinationLocation != null) {
        _mapObjects.add(
          PlacemarkMapObject(
            mapId: const MapObjectId('end'),
            point: _destinationLocation!,
            icon: PlacemarkIcon.single(
              PlacemarkIconStyle(image: BitmapDescriptor.fromBytes(_cachedEndIcon!), scale: 1.0),
            ),
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
    int raw = ((base + _distanceKm * perKm) / 100).round() * 100;
    if (appState.useBonus && appState.clientBonus > 0) {
      raw = max(2000, raw - min(3000, appState.clientBonus));
    }
    return raw;
  }

  void _swapAddresses() async {
    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Almashtirish uchun avval B nuqtani tanlang!"), duration: Duration(seconds: 2)),
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      final Point tempPt = _fromPoint;
      final String tempAddr = _fromAddress;
      _fromPoint = _destinationLocation!;
      _fromAddress = _toAddress;
      _destinationLocation = tempPt;
      _toAddress = tempAddr;
    });
    await _updateMapObjects();
    await _buildRoute(fitCamera: true);
  }

  void _onCameraPositionChanged(CameraPosition pos, CameraUpdateReason reason, bool finished) {
    _cameraCenterPoint = pos.target;
    if (reason != CameraUpdateReason.gestures) return;
    final activeOrd = _activeOrder;
    if (activeOrd != null && activeOrd.status != 'Bekor qilindi' && activeOrd.status != 'Yakunlandi') return;

    if (!finished && !_isDraggingMap) {
      setState(() => _isDraggingMap = true);
    } else if (finished) {
      setState(() => _isDraggingMap = false);
      _geocodeDebounce?.cancel();
      _geocodeDebounce = Timer(const Duration(milliseconds: 260), () async {
        final pt = _cameraCenterPoint;
        if (_pinMode == 'from') {
          setState(() {
            _fromPoint = pt;
            _fromAddress = AppStrings.tr("locating");
          });
          await _updateMapObjects();
          if (_destinationLocation != null) await _buildRoute(fitCamera: false);
          final addr = await _reverseGeocode(pt);
          if (mounted) setState(() => _fromAddress = addr);
        } else {
          setState(() {
            _destinationLocation = pt;
            _isSearchingAddress = true;
            _toAddress = AppStrings.tr("locating");
          });
          await _updateMapObjects();
          await _buildRoute(fitCamera: false);
          final addr = await _reverseGeocode(pt);
          if (mounted) {
            setState(() {
              _toAddress = addr;
              _isSearchingAddress = false;
            });
          }
        }
      });
    }
  }

  // Aqlli qidiruv: Kirill va Lotin, aynan foydalanuvchi turgan shahar/atrofdagi eng yaqin ko'chalar
  void _openLiveAddressSearchSheet({required bool initialFocusTo}) {
    final bool dark = appState.isDarkMode;
    final TextEditingController fromCtrl = TextEditingController(text: _fromAddress);
    final TextEditingController toCtrl = TextEditingController(text: _toAddress);
    bool editingFrom = !initialFocusTo;
    List<AddressSuggestion> suggestions = [];
    bool isLoading = false;
    Timer? debounce;

    Future<void> runSearch(String query, StateSetter setModalState) async {
      final q = query.trim();
      if (q.length < 2) {
        setModalState(() {
          suggestions = [];
          isLoading = false;
        });
        return;
      }

      setModalState(() => isLoading = true);
      try {
        final Point anchor = _cameraCenterPoint;
        final BoundingBox localBox = BoundingBox(
          southWest: Point(latitude: anchor.latitude - 0.35, longitude: anchor.longitude - 0.35),
          northEast: Point(latitude: anchor.latitude + 0.35, longitude: anchor.longitude + 0.35),
        );

        final List<AddressSuggestion> collected = [];
        final Set<String> seenKeys = {};

        Future<void> fetchForText(String searchText) async {
          final session = YandexSearch.searchByText(
            searchText: searchText,
            geometry: Geometry.fromBoundingBox(localBox),
            searchOptions: const SearchOptions(
              searchType: SearchType.geo,
              resultPageSize: 20,
            ),
          );
          final res = await session.result;
          if (res.items != null) {
            for (final item in res.items!) {
              if (item.geometry.isNotEmpty && item.geometry.first.point != null) {
                final pt = item.geometry.first.point!;
                final dist = _calculateStraightDistance(_fromPoint, pt);
                // Uzoq davlat va 120 km dan uzoq hududlarni filtrlab tashlaymiz
                if (dist <= 120.0) {
                  final key = "${pt.latitude.toStringAsFixed(4)}_${pt.longitude.toStringAsFixed(4)}";
                  if (!seenKeys.contains(key)) {
                    seenKeys.add(key);
                    final String sub = item.toponymMetadata?.address.formattedAddress ?? appState.currentCity;
                    collected.add(
                      AddressSuggestion(
                        title: item.name,
                        subtitle: sub,
                        point: pt,
                        distanceKm: dist,
                      ),
                    );
                  }
                }
              }
            }
          }
        }

        // 1. Asl yozilgan matn bo'yicha (Kirill yoki Lotin)
        await fetchForText("${appState.currentCity} $q");
        await fetchForText(q);

        // 2. Agar Kirill harflarida yozilgan bo'lsa, Lotin transliteratsiyasi orqali ham mahalliy bazadan qidiramiz
        final String latinQuery = _cyrillicToLatin(q);
        if (latinQuery != q) {
          await fetchForText(latinQuery);
        }

        // Eng yaqin ko'chalarni birinchi o'ringa chiqaramiz
        collected.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

        setModalState(() {
          suggestions = collected;
          isLoading = false;
        });
      } catch (_) {
        setModalState(() => isLoading = false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: dark ? kDarkBg : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return FractionallySizedBox(
            heightFactor: 0.90,
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 14, right: 14, top: 12),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: dark ? kDarkCard : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: editingFrom ? kPrimaryGreen : Colors.transparent, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Text("A", style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: fromCtrl,
                                  autofocus: !initialFocusTo,
                                  onTap: () => setModalState(() => editingFrom = true),
                                  onChanged: (val) {
                                    editingFrom = true;
                                    debounce?.cancel();
                                    debounce = Timer(const Duration(milliseconds: 280), () => runSearch(val, setModalState));
                                  },
                                  decoration: InputDecoration(
                                    labelText: "Qayerdan",
                                    isDense: true,
                                    border: InputBorder.none,
                                    suffixIcon: fromCtrl.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () => setModalState(() => fromCtrl.clear()),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: "Xaritadan A nuqtani belgilash",
                                icon: const Icon(Icons.pin_drop_outlined, color: kPrimaryGreen),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  setState(() => _pinMode = 'from');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _swapAddresses();
                        },
                        icon: const Icon(Icons.swap_vert, color: kPrimaryGreen, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: dark ? kDarkCard : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: !editingFrom ? kPrimaryGreen : Colors.transparent, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Text("B", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: toCtrl,
                                  autofocus: initialFocusTo,
                                  onTap: () => setModalState(() => editingFrom = false),
                                  onChanged: (val) {
                                    editingFrom = false;
                                    debounce?.cancel();
                                    debounce = Timer(const Duration(milliseconds: 280), () => runSearch(val, setModalState));
                                  },
                                  decoration: InputDecoration(
                                    labelText: "Qayerga",
                                    hintText: AppStrings.tr("search_street"),
                                    isDense: true,
                                    border: InputBorder.none,
                                    suffixIcon: toCtrl.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () => setModalState(() => toCtrl.clear()),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: kPrimaryGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  tooltip: "Xaritadan B nuqtani belgilash",
                                  icon: const Icon(Icons.location_searching, color: kPrimaryGreen),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    setState(() => _pinMode = 'to');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isLoading) const LinearProgressIndicator(color: kPrimaryGreen),
                  Expanded(
                    child: suggestions.isEmpty
                        ? ListView.separated(
                            itemCount: appState.favorites.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final fav = appState.favorites[idx];
                              return ListTile(
                                leading: const Icon(Icons.star, color: kAccentYellow),
                                title: Text(fav.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(fav.address, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  if (editingFrom) {
                                    setState(() {
                                      _fromPoint = fav.point;
                                      _fromAddress = fav.title;
                                    });
                                    await _updateMapObjects();
                                    if (_destinationLocation != null) await _buildRoute();
                                  } else {
                                    setState(() {
                                      _destinationLocation = fav.point;
                                      _toAddress = fav.title;
                                      _pinMode = 'to';
                                    });
                                    await _updateMapObjects();
                                    await _buildRoute();
                                  }
                                },
                              );
                            },
                          )
                        : ListView.separated(
                            itemCount: suggestions.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final item = suggestions[idx];
                              return ListTile(
                                leading: const Icon(Icons.location_on_outlined, color: kPrimaryGreen),
                                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Text(
                                  item.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: Text(
                                  "${item.distanceKm} km",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryGreen),
                                ),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  if (editingFrom) {
                                    setState(() {
                                      _fromPoint = item.point;
                                      _fromAddress = item.title;
                                    });
                                    await _updateMapObjects();
                                    if (_destinationLocation != null) await _buildRoute();
                                  } else {
                                    setState(() {
                                      _destinationLocation = item.point;
                                      _toAddress = item.title;
                                      _pinMode = 'to';
                                    });
                                    await _updateMapObjects();
                                    await _buildRoute();
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openWishesDialog() {
    final options = [
      "Konditsioner yoqilsin",
      "Yukxona bo'sh bo'lsin",
      "Bolalar o'rindig'i kerak",
      "Haydovchi qo'ng'iroq qilmasin",
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setWState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.tr("wishes"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                ...options.map(
                  (w) => CheckboxListTile(
                    activeColor: kPrimaryGreen,
                    title: Text(w),
                    value: _selectedWishes.contains(w),
                    onChanged: (val) {
                      setWState(() {
                        if (val == true) {
                          _selectedWishes.add(w);
                        } else {
                          _selectedWishes.remove(w);
                        }
                      });
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("TAYYOR", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitOrder() {
    if (_destinationLocation == null) {
      HapticFeedback.vibrate();
      _openLiveAddressSearchSheet(initialFocusTo: true);
      return;
    }

    final newOrder = OrderModel(
      id: "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
      clientPhone: appState.userPhone,
      fromAddress: _fromAddress,
      toAddress: _toAddress,
      fromPoint: _fromPoint,
      toPoint: _destinationLocation!,
      tariff: _serviceMode == 'Dostavka' ? 'Dostavka' : _selectedTariff,
      distanceKm: _distanceKm,
      price: _getPrice(_serviceMode == 'Dostavka' ? 'Dostavka' : _selectedTariff),
      wishes: List<String>.from(_selectedWishes),
      createdAt: DateTime.now(),
    );

    appState.createOrder(newOrder);
    setState(() => _activeOrderId = newOrder.id);
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder orqali Firebase'dan kelgan har bir o'zgarish shu zahoti ekranda yangilanadi!
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final int pendingCount = appState.orders.where((o) => o.status == 'Kutilmoqda').length;
        final OrderModel? activeOrd = _activeOrder;
        final bool dark = appState.isDarkMode;

        return Scaffold(
          body: Stack(
            children: [
              YandexMap(
                nightModeEnabled: dark,
                mapObjects: _mapObjects,
                onMapCreated: (controller) async {
                  _mapController = controller;
                  await _determinePosition(immediateJump: true);
                },
                onCameraPositionChanged: _onCameraPositionChanged,
                onMapTap: (point) async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (activeOrd != null && activeOrd.status != 'Bekor qilindi' && activeOrd.status != 'Yakunlandi') return;

                  setState(() {
                    _destinationLocation = point;
                    _isSearchingAddress = true;
                    _toAddress = AppStrings.tr("locating");
                    _pinMode = 'to';
                  });
                  await _updateMapObjects();
                  await _buildRoute(fitCamera: false);
                  final addrName = await _reverseGeocode(point);
                  if (mounted) {
                    setState(() {
                      _toAddress = addrName;
                      _isSearchingAddress = false;
                    });
                  }
                },
              ),

              if (activeOrd == null || activeOrd.status == 'Bekor qilindi')
                IgnorePointer(
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.only(bottom: _isDraggingMap ? 210 : 185),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kDarkBg.withOpacity(0.92),
                              border: Border.all(
                                color: _pinMode == 'from' ? kPrimaryGreen : Colors.redAccent,
                                width: 3.5,
                              ),
                              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                            ),
                            alignment: Alignment.center,
                            child: _isDraggingMap
                                ? Text(
                                    _pinMode == 'from' ? "A" : "B",
                                    style: TextStyle(
                                      color: _pinMode == 'from' ? kPrimaryGreen : Colors.redAccent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                    ),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text("1", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, height: 1.0)),
                                      Text("min", style: TextStyle(color: Colors.white70, fontSize: 10, height: 1.0)),
                                    ],
                                  ),
                          ),
                          Container(
                            width: 3,
                            height: 14,
                            color: _pinMode == 'from' ? kPrimaryGreen : Colors.redAccent,
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _pinMode == 'from' ? kPrimaryGreen : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 14,
                child: Row(
                  children: [
                    FloatingActionButton.small(
                      heroTag: "menu_btn",
                      backgroundColor: dark ? kDarkCard : Colors.white,
                      onPressed: widget.onOpenMenu,
                      child: const Icon(Icons.menu, color: kPrimaryGreen),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() => _pinMode = _pinMode == 'from' ? 'to' : 'from');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: (dark ? kDarkCard : Colors.white).withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pin_drop,
                              size: 16,
                              color: _pinMode == 'from' ? kPrimaryGreen : Colors.redAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _pinMode == 'from' ? "To'g'nag'ich: A" : "To'g'nag'ich: B",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: dark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (dark ? kDarkCard : Colors.white).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.card_giftcard, color: kPrimaryGreen, size: 20),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AppStrings.tr("bonuses"), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            "${appState.clientBonus}",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: dark ? Colors.white : Colors.black),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Switch(
                        activeColor: kPrimaryGreen,
                        value: appState.useBonus,
                        onChanged: (v) => setState(() => appState.useBonus = v),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                right: 14,
                bottom: 335,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (pendingCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
                          onPressed: () => widget.onQuickRoleSwitch(1),
                          icon: const Icon(Icons.notifications_active, size: 16),
                          label: Text("Haydovchi ($pendingCount)"),
                        ),
                      ),
                    FloatingActionButton.small(
                      heroTag: "gps_btn",
                      backgroundColor: dark ? kDarkCard : Colors.white,
                      onPressed: () {
                        setState(() => _pinMode = 'from');
                        _determinePosition(immediateJump: false);
                      },
                      child: const Icon(Icons.my_location, color: kPrimaryGreen),
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  decoration: BoxDecoration(
                    color: dark ? kDarkBg : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18)],
                  ),
                  child: activeOrd != null && activeOrd.status != 'Bekor qilindi'
                      ? _buildActiveOrderUI(activeOrd, dark)
                      : _buildBookingUI(dark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveOrderUI(OrderModel ord, bool dark) {
    final st = ord.status;
    if (st == 'Yakunlandi') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: kPrimaryGreen, size: 48),
          const SizedBox(height: 6),
          const Text("Safar muvaffaqiyatli yakunlandi!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 4),
          Text("To'lov: ${ord.price} so'm (${ord.distanceKm} km)", style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
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
      statusTitle = "Haydovchi qabul qildi, yo'lga chiqdi!";
    } else if (st == 'Yetib keldi') {
      badgeColor = kPrimaryGreen;
      statusTitle = "Haydovchi yetib keldi, sizni kutmoqda!";
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
            Text("${ord.price} so'm", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kPrimaryGreen)),
          ],
        ),
        const SizedBox(height: 10),
        Text(statusTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        if (ord.driverName != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: dark ? kDarkCard : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const CircleAvatar(backgroundColor: kPrimaryGreen, child: Icon(Icons.drive_eta, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ord.driverName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(ord.driverCar ?? "", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else
          const LinearProgressIndicator(color: kPrimaryGreen),
        const SizedBox(height: 12),
        if (st != 'Safarda')
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
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

  Widget _buildBookingUI(bool dark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  InkWell(
                    onTap: () => _openLiveAddressSearchSheet(initialFocusTo: false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 24,
                            child: Text("A", style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.w900, fontSize: 16)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fromAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(appState.currentCity, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 10),
                  InkWell(
                    onTap: () => _openLiveAddressSearchSheet(initialFocusTo: true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 24,
                            child: Text("B", style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.w900, fontSize: 16)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isSearchingAddress
                                      ? AppStrings.tr("locating")
                                      : (_toAddress.isEmpty ? AppStrings.tr("to_hint") : _toAddress),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _toAddress.isEmpty ? Colors.grey : null,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (_destinationLocation != null)
                                  Text(
                                    "${appState.currentCity} • $_distanceKm km (~$_etaMinutes daq)",
                                    style: const TextStyle(fontSize: 11, color: kPrimaryGreen, fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: "A va B o'rnini almashtirish",
                  onPressed: _swapAddresses,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kPrimaryGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.swap_vert, color: kPrimaryGreen, size: 22),
                  ),
                ),
                IconButton(
                  tooltip: "Manzil qidirish",
                  onPressed: () => _openLiveAddressSearchSheet(initialFocusTo: true),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: kPrimaryGreen, shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _serviceChip("Taksi", AppStrings.tr("taxi")),
            const SizedBox(width: 8),
            _serviceChip("Dostavka", AppStrings.tr("delivery")),
          ],
        ),
        const SizedBox(height: 10),
        if (_serviceMode == 'Taksi')
          Row(
            children: [
              _tariffCard("Standart", AppStrings.tr("standard"), Icons.local_taxi, dark),
              const SizedBox(width: 10),
              _tariffCard("Komfort", AppStrings.tr("comfort"), Icons.directions_car_filled, dark),
            ],
          )
        else
          _tariffCard("Dostavka", AppStrings.tr("delivery"), Icons.local_shipping, dark),
        const SizedBox(height: 10),
        InkWell(
          onTap: _openWishesDialog,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.tune, color: kPrimaryGreen, size: 18),
                const SizedBox(width: 6),
                Text(
                  _selectedWishes.isEmpty ? AppStrings.tr("wishes") : "${AppStrings.tr("wishes")} (${_selectedWishes.length})",
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            onPressed: _submitOrder,
            child: Text(
              _destinationLocation == null
                  ? AppStrings.tr("order_btn")
                  : "${AppStrings.tr("order_btn")} • ${_getPrice(_serviceMode == 'Dostavka' ? 'Dostavka' : _selectedTariff)} so'm",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _serviceChip(String key, String label) {
    final bool selected = _serviceMode == key;
    return GestureDetector(
      onTap: () => setState(() => _serviceMode = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kPrimaryGreen : Colors.grey.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _tariffCard(String key, String title, IconData icon, bool dark) {
    final bool selected = _selectedTariff == key || _serviceMode == 'Dostavka';
    final int price = _getPrice(key);
    return GestureDetector(
      onTap: () => setState(() => _selectedTariff = key),
      child: Container(
        width: 128,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: dark ? kDarkCard : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? kPrimaryGreen : Colors.transparent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
                  child: const Text("1 daq", style: TextStyle(fontSize: 10, color: Colors.white70)),
                ),
                Icon(icon, color: key == 'Standart' ? kAccentYellow : Colors.blueGrey, size: 22),
              ],
            ),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(
              _destinationLocation == null ? "min $price so'm" : "$price so'm",
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kPrimaryGreen),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverTerminalScreen extends StatelessWidget {
  final AppState state;
  const DriverTerminalScreen({super.key, required this.state});

  void _showDriverSelfRegister(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: "+998 90 ");
    final carCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    String tariff = "Standart";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text("Yangi haydovchi bo'lib ulanish"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ism va Familiyangiz")),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefon raqamingiz")),
                TextField(controller: carCtrl, decoration: const InputDecoration(labelText: "Mashina rusumi va rangi (Oq Cobalt)")),
                TextField(controller: numCtrl, decoration: const InputDecoration(labelText: "Davlat raqami (75 A 777 AA)")),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: tariff,
                  decoration: const InputDecoration(labelText: "Tarif"),
                  items: ["Standart", "Komfort", "Dostavka"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDState(() => tariff = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                state.addDriver(
                  nameCtrl.text.trim(),
                  phoneCtrl.text.trim(),
                  carCtrl.text.trim().isEmpty ? "Oq Cobalt" : carCtrl.text.trim(),
                  numCtrl.text.trim().isEmpty ? "75 A 123 AA" : numCtrl.text.trim(),
                  tariff,
                  100000,
                );
                Navigator.pop(ctx);
              },
              child: const Text("ULANISH"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final driver = state.drivers[state.activeDriverIndex];
        final pendingOrders = state.orders.where((o) => o.status == 'Kutilmoqda').toList();
        final activeOrders = state.orders
            .where((o) => o.driverId == driver.id && o.status != 'Kutilmoqda' && o.status != 'Yakunlandi' && o.status != 'Bekor qilindi')
            .toList();

        return Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kDarkCard, borderRadius: BorderRadius.circular(16)),
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
                            Text("${driver.balance} so'm", style: const TextStyle(color: kAccentYellow, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("Safarlar: ${driver.trips} ta", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
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
                              style: const TextStyle(color: kAccentYellow, fontWeight: FontWeight.bold, fontSize: 13),
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
                                  state.saveToStorage();
                                  state.notifyListeners();
                                }
                              },
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showDriverSelfRegister(context),
                          icon: const Icon(Icons.person_add_alt_1, color: kPrimaryGreen, size: 16),
                          label: const Text("Yangi", style: TextStyle(color: kPrimaryGreen, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (activeOrders.isNotEmpty) ...[
                const Text("Joriy bajarilayotgan buyurtma:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryGreen)),
                const SizedBox(height: 6),
                ...activeOrders.map(
                  (ord) => Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kPrimaryGreen, width: 1.5)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${ord.tariff} • ${ord.distanceKm} km", style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text("${ord.price} so'm", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kPrimaryGreen)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text("📍 Oladi: ${ord.fromAddress}", style: const TextStyle(fontSize: 13)),
                          Text("🏁 Boradi: ${ord.toAddress}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
                              onPressed: () {
                                String next = 'Yetib keldi';
                                if (ord.status == 'Yetib keldi') next = 'Safarda';
                                if (ord.status == 'Safarda') next = 'Yakunlandi';
                                state.updateOrderStatus(ord.id, next, driver);
                              },
                              child: Text(
                                ord.status == 'Qabul qilindi'
                                    ? "MANZILGA YETIB KELDIM"
                                    : ord.status == 'Yetib keldi'
                                        ? "SAFARNI BOSHLASH"
                                        : "SAFARNI YAKUNLASH",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Yangi buyurtmalar (${pendingOrders.length}):", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18, color: kPrimaryGreen),
                        onPressed: () => state.syncFromFirebase(),
                      ),
                      Text(
                        state.isFirebaseConnected ? "Firebase Online" : "Lokal",
                        style: const TextStyle(color: kPrimaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
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
                                        decoration: BoxDecoration(color: kAccentYellow, borderRadius: BorderRadius.circular(6)),
                                        child: Text(ord.tariff, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                                      ),
                                      Text("${ord.price} so'm", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: kPrimaryGreen)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text("📍 Oladi: ${ord.fromAddress}", style: const TextStyle(fontSize: 13)),
                                  const SizedBox(height: 3),
                                  Text("🏁 Boradi: ${ord.toAddress}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  if (ord.wishes.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text("Istaklar: ${ord.wishes.join(', ')}", style: const TextStyle(fontSize: 12, color: Colors.orange)),
                                    ),
                                  const SizedBox(height: 4),
                                  Text("Masofa: ${ord.distanceKm} km • Mijoz: ${ord.clientPhone}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kPrimaryGreen,
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
      },
    );
  }
}

class OperatorView extends StatefulWidget {
  final AppState state;
  const OperatorView({super.key, required this.state});
  @override
  State<OperatorView> createState() => _OperatorViewState();
}

class _OperatorViewState extends State<OperatorView> {
  final TextEditingController _phoneCtrl = TextEditingController(text: "+998 90 ");
  final TextEditingController _fromCtrl = TextEditingController(text: "Markaz");
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _kmCtrl = TextEditingController(text: "3.0");
  String _tariff = "Standart";

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
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
                          style: ElevatedButton.styleFrom(backgroundColor: kAccentYellow, foregroundColor: Colors.black),
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
                                id: "OP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
                                clientPhone: _phoneCtrl.text.trim(),
                                fromAddress: _fromCtrl.text.trim(),
                                toAddress: _toCtrl.text.trim(),
                                fromPoint: const Point(latitude: 41.3111, longitude: 69.2797),
                                toPoint: const Point(latitude: 41.3200, longitude: 69.2900),
                                tariff: _tariff,
                                distanceKm: km,
                                price: price,
                                createdAt: DateTime.now(),
                              ),
                            );
                            _toCtrl.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Buyurtma barcha haydovchilarga yuborildi!"), backgroundColor: kPrimaryGreen),
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
                              subtitle: Text("Oladi: ${o.fromAddress}\nHolat: ${o.status} • Haydovchi: ${o.driverName ?? 'Biriktirilmagan'}"),
                              isThreeLine: true,
                              trailing: o.status == 'Kutilmoqda'
                                  ? IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => widget.state.cancelOrder(o.id))
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
    String tariff = "Standart";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text("Yangi haydovchi qo'shish", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "F.I.Sh")),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefon raqami")),
                TextField(controller: carCtrl, decoration: const InputDecoration(labelText: "Mashina rusumi va rangi")),
                TextField(controller: numCtrl, decoration: const InputDecoration(labelText: "Davlat raqami")),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: tariff,
                  decoration: const InputDecoration(labelText: "Tarif toifasi"),
                  items: ["Standart", "Komfort", "Dostavka"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDState(() => tariff = v!),
                ),
                TextField(controller: balCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Boshlang'ich balans")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                widget.state.addDriver(
                  nameCtrl.text.trim(),
                  phoneCtrl.text.trim(),
                  carCtrl.text.trim().isEmpty ? "Oq Cobalt" : carCtrl.text.trim(),
                  numCtrl.text.trim().isEmpty ? "75 A 000 AA" : numCtrl.text.trim(),
                  tariff,
                  int.tryParse(balCtrl.text) ?? 100000,
                );
                Navigator.pop(ctx);
              },
              child: const Text("SAQLASH"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
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
                      const Text("Tarif va Komissiya (Firebase orqali barchada yangilanadi)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
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
                              const SnackBar(content: Text("Tariflar Firebase bazasida saqlandi!"), backgroundColor: kPrimaryGreen),
                            );
                          },
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text("SAQLASH", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    style: ElevatedButton.styleFrom(backgroundColor: kDarkCard, foregroundColor: kAccentYellow),
                    onPressed: _showAddDriverDialog,
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text("Qo'shish"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...widget.state.drivers.map(
                (d) => Card(
                  child: ListTile(
                    title: Text("${d.name} (${d.carNumber})", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${d.carModel} • ${d.tariffType} • Balans: ${d.balance} so'm"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () => widget.state.topUpDriverBalance(d.id, 50000),
                          icon: const Icon(Icons.add_circle, color: kPrimaryGreen, size: 18),
                          label: const Text("+50m", style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold)),
                        ),
                        if (widget.state.drivers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => widget.state.deleteDriver(d.id),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
