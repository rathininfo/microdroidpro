import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String defaultServerUrl = "http://192.168.0.105:3000/ivac-sms";
const String notificationChannelId = 'ivac_sms_foreground_service';
const int notificationId = 888;

/// Top-level background SMS handler (must be @pragma('vm:entry-point'))
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("📩 [BACKGROUND SMS RECEIVED]: ${message.address} -> ${message.body}");
  await processAndForwardSms(message.address, message.body);
}

/// Helper method to filter IVAC / OTP keywords and POST to server
Future<bool> processAndForwardSms(String? sender, String? body) async {
  if (body == null || body.isEmpty) return false;

  final upperBody = body.toUpperCase();
  // Filter for IVAC or OTP keywords
  final isIvacRelated = upperBody.contains('IVAC') || upperBody.contains('OTP');

  if (!isIvacRelated) {
    debugPrint("⏩ Ignored non-IVAC SMS from: $sender");
    return false;
  }

  debugPrint("🎯 Matched IVAC/OTP SMS! Forwarding to server...");

  // Retrieve saved server URL
  final prefs = await SharedPreferences.getInstance();
  final targetUrl = prefs.getString('server_url') ?? defaultServerUrl;

  try {
    final response = await http.post(
      Uri.parse(targetUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender': sender ?? 'Unknown',
        'message': body,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      debugPrint("✅ SMS successfully sent to Node.js server! Response: ${response.body}");
      return true;
    } else {
      debugPrint("❌ Server returned HTTP ${response.statusCode}: ${response.body}");
      return false;
    }
  } catch (e) {
    debugPrint("❌ Failed to forward SMS to $targetUrl: $e");
    return false;
  }
}

/// Initialize Background Service
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    'IVAC SMS Monitor Service',
    description: 'Keeps SMS monitoring active 24/7 in background',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: true,
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'IVAC SMS Monitor Active',
      initialNotificationContent: 'Monitoring incoming OTP in background...',
      foregroundServiceNotificationId: notificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onServiceStart,
    ),
  );
}

/// Service Entry Point
@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  final Telephony telephony = Telephony.instance;

  debugPrint("🚀 [Service Started] Listening to Telephony incoming SMS...");

  // Register Incoming SMS listener for both Foreground & Background
  telephony.listenIncomingSms(
    onNewMessage: (SmsMessage message) async {
      debugPrint("📩 [FOREGROUND SMS RECEIVED]: ${message.address} -> ${message.body}");
      final forwarded = await processAndForwardSms(message.address, message.body);

      // Notify UI via service event
      service.invoke('onSmsForwarded', {
        'sender': message.address ?? 'Unknown',
        'body': message.body ?? '',
        'time': DateTime.now().toIso8601String(),
        'success': forwarded,
      });
    },
    onBackgroundMessage: backgroundMessageHandler,
    listenInBackground: true,
  );

  // Keep foreground notification refreshed
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  // Periodic heartbeat every 60s
  Timer.periodic(const Duration(seconds: 60), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "IVAC SMS Service Running",
          content: "Active | Last sync: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
        );
      }
    }
  });
}
