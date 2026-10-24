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
    if (idx != -1
