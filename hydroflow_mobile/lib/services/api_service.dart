import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

class ApiService {
  static const String baseUrl = AppConstants.baseUrl;

  static String? _token;
  static Map<String, dynamic>? _user;

  // Screens that display the user's name listen to this notifier.
  static final userNotifier = ValueNotifier<Map<String, dynamic>?>(null);

  static String? getToken() => _token;
  static Map<String, dynamic>? getUser() => _user;
  static bool get isLoggedIn => _token != null;

  // Called on 401 — cleared storage, then optionally navigates to login.
  // Wire this in main.dart: ApiService.onUnauthorized = () { navigatorKey... }
  static void Function()? onUnauthorized;

  static Future<void> _handleUnauthorized() async {
    await clearStorage();
    onUnauthorized?.call();
  }

  // Persist token and user to device storage
  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aq_token', token);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    _user = user;
    userNotifier.value = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aq_user', jsonEncode(user));
  }

  // Load saved session on app start
  static Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('aq_token');
    final userStr = prefs.getString('aq_user');
    if (userStr != null) _user = jsonDecode(userStr) as Map<String, dynamic>;
  }

  static Future<void> clearStorage() async {
    _token = null; _user = null;
    userNotifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('aq_token');
    await prefs.remove('aq_user');
  }

  static Future<void> logout() => clearStorage();

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── AUTH ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String phone, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'password': password}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        saveToken(data['token']);
        saveUser(data['user']);
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    String role = 'resident',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'phone': phone, 'email': email, 'password': password, 'role': role}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 201) return {'success': true, 'message': data['message']};
      return {'success': false, 'message': data['message'] ?? 'Registration failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  // ── PRODUCTS ──────────────────────────────────────────
  static Future<List<dynamic>> getProducts() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/products'), headers: _headers);
      if (res.statusCode == 200) return jsonDecode(res.body)['products'] ?? [];
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── ORDERS ────────────────────────────────────────────
  static Future<Map<String, dynamic>> createOrder({
    String? productId,
    required int volumeLiters,
    required double amountKsh,
    required double deliveryFee,
    required String deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? notes,
    int quantity = 1,
    bool returnEmpties = false,
  }) async {
    try {
      final body = {
        'volume_liters': volumeLiters,
        'amount_ksh': amountKsh,
        'delivery_fee': deliveryFee,
        'delivery_address': deliveryAddress,
        'quantity': quantity,
        'return_empties': returnEmpties,
        if (productId != null) 'product_id': productId,
        if (deliveryLat != null) 'delivery_lat': deliveryLat,
        if (deliveryLng != null) 'delivery_lng': deliveryLng,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };
      final res = await http.post(Uri.parse('$baseUrl/orders'), headers: _headers, body: jsonEncode(body));
      final data = jsonDecode(res.body);
      if (res.statusCode == 201) return {'success': true, 'order': data['order'], 'message': data['message']};
      return {'success': false, 'message': data['message'] ?? 'Order failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<List<dynamic>> getMyOrders() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/orders'), headers: _headers);
      if (res.statusCode == 200) return jsonDecode(res.body)['orders'] ?? [];
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getDriverOrders() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/orders/driver'), headers: _headers);
      if (res.statusCode == 200) return jsonDecode(res.body)['orders'] ?? [];
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/orders/$orderId/status'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'order': data['order']};
      return {'success': false, 'message': data['message'] ?? 'Failed to update'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> rateOrder(String orderId, int rating) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/rate'),
        headers: _headers,
        body: jsonEncode({'rating': rating}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true};
      return {'success': false, 'message': data['message'] ?? 'Rating failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  // Resident confirms a DELIVERED order was received — required before it can be rated.
  static Future<Map<String, dynamic>> confirmDelivery(String orderId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/quality/orders/$orderId/verify'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'order': data['order']};
      return {'success': false, 'message': data['message'] ?? 'Could not confirm delivery'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  // ── M-PESA ───────────────────────────────────────────
  static Future<Map<String, dynamic>> initiatePayment({
    required String orderId,
    String? phone,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/mpesa/pay'),
        headers: _headers,
        body: jsonEncode({
          'order_id': orderId,
          if (phone != null) 'phone': phone,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'data': data};
      return {'success': false, 'message': data['message'] ?? 'Payment failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> checkPaymentStatus({required String orderId}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/mpesa/status/$orderId'), headers: _headers);
      if (res.statusCode == 200) return {'success': true, 'data': jsonDecode(res.body)};
      return {'success': false, 'message': 'Failed to check status'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  // ── DRIVERS ──────────────────────────────────────────
  static Future<Map<String, dynamic>> toggleAvailability(bool isAvailable) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/drivers/availability'),
        headers: _headers,
        body: jsonEncode({'is_available': isAvailable}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'driver': data['driver']};
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  // Set driver status: 'available' or 'offline'
  static Future<Map<String, dynamic>> updateDriverStatus(String status) async {
    try {
      final request = http.Request('PATCH', Uri.parse('$baseUrl/drivers/status'));
      request.headers.addAll(_headers);
      request.body = jsonEncode({'status': status});
      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'driver': data['driver']};
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> updateLocation(double lat, double lng) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/drivers/location'),
        headers: _headers,
        body: jsonEncode({'lat': lat, 'lng': lng}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true};
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  // Push driver GPS to the self-service location endpoint (used by driver screen)
  static Future<Map<String, dynamic>> pushDriverLocation(double lat, double lng) async {
    try {
      final req = http.Request('PATCH', Uri.parse('$baseUrl/driver/location'));
      req.headers.addAll(_headers);
      req.body = jsonEncode({'lat': lat, 'lng': lng});
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 401) { await _handleUnauthorized(); return {'success': false}; }
      if (res.statusCode == 200) return {'success': true};
      return {'success': false};
    } catch (e) {
      return {'success': false};
    }
  }

  static Future<Map<String, dynamic>> sendOtp({
    required String phone,
    String role = 'resident',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'role': role}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {'success': true, 'message': 'OTP sent successfully'};
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to send OTP'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String role = 'resident',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otp': otp, 'role': role}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final token = data['token'] as String?;
        final user = data['user'] as Map<String, dynamic>?;
        if (token != null && user != null) {
          await saveToken(token);
          await saveUser(user);
          return {'success': true, 'user': user};
        }
      }
      return {'success': false, 'message': data['message'] ?? 'Invalid OTP'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? vehicleInfo,
    String? vehiclePlate,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (vehicleInfo != null) body['vehicle_info'] = vehicleInfo;
      if (vehiclePlate != null) body['vehicle_plate'] = vehiclePlate;

      final res = await http.put(
        Uri.parse('$baseUrl/users/me'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 401) { await _handleUnauthorized(); return {'success': false, 'unauthorized': true}; }
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final updatedUser = data['user'] as Map<String, dynamic>?;
        if (updatedUser != null) {
          _user = {...?_user, ...updatedUser};
          await saveUser(_user!);
        }
        return {'success': true, 'user': updatedUser};
      }
      return {'success': false, 'message': data['message'] ?? 'Update failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> getMe() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/users/me'), headers: _headers);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final user = data['user'] as Map<String, dynamic>?;
        if (user != null) await saveUser(user);
        return {'success': true, 'user': user};
      }
      if (res.statusCode == 401) { await _handleUnauthorized(); return {'success': false, 'unauthorized': true}; }
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  // ── SINGLE ORDER ─────────────────────────────────────
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/orders/$orderId'), headers: _headers);
      if (res.statusCode == 401) { await _handleUnauthorized(); return {'success': false, 'unauthorized': true}; }
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'order': data['order']};
      return {'success': false, 'message': data['message'] ?? 'Order not found'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  // ── ORDER TRACKING (poll every 5s) ───────────────────
  static Future<Map<String, dynamic>> getOrderTracking(String orderId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/orders/$orderId/tracking'), headers: _headers);
      if (res.statusCode == 401) { await _handleUnauthorized(); return {'success': false, 'unauthorized': true}; }
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'tracking': data['tracking']};
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  // ── CANCEL ORDER ─────────────────────────────────────
  static Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/cancel'),
        headers: _headers,
      );
      if (res.statusCode == 401) { await _handleUnauthorized(); return {'success': false, 'unauthorized': true}; }
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'order': data['order']};
      return {'success': false, 'message': data['message'] ?? 'Cannot cancel order'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  // ── M-PESA STK PUSH (spec path) ──────────────────────
  static Future<Map<String, dynamic>> stkPush(String orderId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/payments/mpesa/stkpush'),
        headers: _headers,
        body: jsonEncode({'order_id': orderId}),
      );
      if (res.statusCode == 401) { await _handleUnauthorized(); return {'success': false, 'unauthorized': true}; }
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'data': data};
      return {'success': false, 'message': data['message'] ?? 'Payment failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  // ── DRIVER SELF-SERVICE (/api/driver/) ───────────────
  static Future<List<dynamic>> getDriverDeliveries() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/driver/deliveries'), headers: _headers);
      if (res.statusCode == 401) { await _handleUnauthorized(); return []; }
      if (res.statusCode == 200) return jsonDecode(res.body)['deliveries'] ?? [];
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getDriverDeliveryById(String id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/driver/deliveries/$id'), headers: _headers);
      if (res.statusCode == 401) { await _handleUnauthorized(); return {'success': false, 'unauthorized': true}; }
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'delivery': data['delivery']};
      return {'success': false, 'message': data['message'] ?? 'Not found'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> updateDriverDeliveryStatus(String id, String status) async {
    try {
      final req = http.Request('PATCH', Uri.parse('$baseUrl/driver/deliveries/$id/status'));
      req.headers.addAll(_headers);
      req.body = jsonEncode({'status': status});
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 401) { await _handleUnauthorized(); return {'success': false, 'unauthorized': true}; }
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'delivery': data['delivery']};
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  // Submits proof of delivery. photoBytes/signatureBytes (if provided) are uploaded to
  // Cloudinary server-side and the resulting URLs are stored against the order.
  static Future<Map<String, dynamic>> submitProof(
    String orderId, {
    int emptyCollected = 0,
    String? notes,
    Uint8List? photoBytes,
    Uint8List? signatureBytes,
  }) async {
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/driver/deliveries/$orderId/proof'));
      if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
      req.fields['empty_collected'] = emptyCollected.toString();
      if (notes != null) req.fields['notes'] = notes;
      if (photoBytes != null) {
        req.files.add(http.MultipartFile.fromBytes('photo', photoBytes,
            filename: 'proof_photo.jpg'));
      }
      if (signatureBytes != null) {
        req.files.add(http.MultipartFile.fromBytes(
            'signature', signatureBytes,
            filename: 'signature.png'));
      }
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 401) { await _handleUnauthorized(); return {'success': false, 'unauthorized': true}; }
      final data = jsonDecode(res.body);
      if (res.statusCode == 201) return {'success': true, 'proof': data['proof']};
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> getDriverEarnings() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/driver/earnings'), headers: _headers);
      if (res.statusCode == 401) { await _handleUnauthorized(); return {'success': false, 'unauthorized': true}; }
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> setDriverOnline(bool isOnline) async {
    try {
      final req = http.Request('PATCH', Uri.parse('$baseUrl/driver/status'));
      req.headers.addAll(_headers);
      req.body = jsonEncode({'is_online': isOnline});
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 401) { await _handleUnauthorized(); return {'success': false, 'unauthorized': true}; }
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'is_online': data['is_online']};
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }
}
