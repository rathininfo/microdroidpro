import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();
  runApp(const IvacForwarderApp());
}

class IvacForwarderApp extends StatelessWidget {
  const IvacForwarderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IVAC SMS Forwarder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F0FF),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isServiceRunning = false;
  String _smsPermissionStatus = "Checking...";
  final List<Map<String, dynamic>> _forwardedLogs = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkPermissions();
    _listenToServiceEvents();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('server_url') ?? defaultServerUrl;
    setState(() {
      _urlController.text = savedUrl;
    });

    final isRunning = await FlutterBackgroundService().isRunning();
    setState(() {
      _isServiceRunning = isRunning;
    });
  }

  Future<void> _checkPermissions() async {
    final smsStatus = await Permission.sms.status;
    await Permission.notification.status;
    await Permission.ignoreBatteryOptimizations.status;

    if (mounted) {
      setState(() {
        _smsPermissionStatus = smsStatus.isGranted ? "অনুমোদিত (Granted)" : "অনুমতি প্রয়োজন (Denied)";
      });
    }
  }

  Future<void> _requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.sms,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
    ].request();

    if (statuses[Permission.sms]?.isGranted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ SMS পারমিশন সফলভাবে দেওয়া হয়েছে!')),
      );
    }
    _checkPermissions();
  }

  void _listenToServiceEvents() {
    const MethodChannel channel = MethodChannel('com.example.ivac_sms_forwarder/sms');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived' && mounted) {
        final data = call.arguments as Map<dynamic, dynamic>?;
        if (data != null) {
          setState(() {
            _forwardedLogs.insert(0, {
              'sender': data['sender'] ?? 'Unknown',
              'body': data['message'] ?? '',
              'time': data['timestamp'] ?? '',
              'success': true,
            });
          });
        }
      }
    });
  }

  Future<void> _saveServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _urlController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('💾 সার্ভার URL সংরক্ষণ করা হয়েছে!')),
      );
    }
  }

  Future<void> _sendTestSms() async {
    final targetUrl = _urlController.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📤 সার্ভারে টেস্ট SMS পাঠানো হচ্ছে...')),
    );

    try {
      final response = await http.post(
        Uri.parse(targetUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': 'IVAC-TEST',
          'message': 'Your IVAC test OTP is 987654. Sent from Flutter App directly.',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text('✅ সার্ভার টেস্ট সফল! কোড: ${response.body}'),
            ),
          );
        }
      } else {
        throw Exception("Server status ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('❌ সার্ভার কানেকশন এরর: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IVAC SMS Forwarder'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadSettings();
              _checkPermissions();
            },
            tooltip: 'রিফ্রেশ',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ব্যাকগ্রাউন্ড সার্ভিস স্ট্যাটাস:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isServiceRunning ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isServiceRunning ? Colors.green : Colors.red,
                            ),
                          ),
                          child: Text(
                            _isServiceRunning ? '🟢 রানিং (24/7 Active)' : '🔴 বন্ধ আছে',
                            style: TextStyle(
                              color: _isServiceRunning ? Colors.greenAccent : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('SMS পারমিশন:', style: TextStyle(color: Colors.white70)),
                        Text(
                          _smsPermissionStatus,
                          style: TextStyle(
                            color: _smsPermissionStatus.contains('Granted') ? Colors.cyanAccent : Colors.orangeAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _requestAllPermissions,
                      icon: const Icon(Icons.security, size: 18),
                      label: const Text('প্রয়োজনীয় সকল পারমিশন প্রদান করুন'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00F0FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Server URL Configuration Card
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'নোড জেএস সার্ভার এন্ডপয়েন্ট (Node.js Server URL)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'কম্পিউটার ও ফোন একই ওয়াইফাই/হটস্পটে থাকলে কম্পিউটারের লোকাল আইপি দিন।',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlController,
                      style: const TextStyle(fontFamily: 'monospace', color: Colors.cyanAccent),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.dns, color: Colors.cyanAccent),
                        hintText: 'http://192.168.x.x:3000/ivac-sms',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saveServerUrl,
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('সংরক্ষণ করুন'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _sendTestSms,
                            icon: const Icon(Icons.send, size: 18),
                            label: const Text('টেস্ট পিং পাঠান'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Live Activity Log
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ফরওয়ার্ডিং লগ (Recent Activity)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    if (_forwardedLogs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'এখনো কোনো মেসেজ ফরওয়ার্ড করা হয়নি',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _forwardedLogs.length,
                        itemBuilder: (context, index) {
                          final log = _forwardedLogs[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              log['success'] == true ? Icons.check_circle : Icons.error,
                              color: log['success'] == true ? Colors.green : Colors.red,
                            ),
                            title: Text(log['sender'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(log['body'], maxLines: 2, overflow: TextOverflow.ellipsis),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
