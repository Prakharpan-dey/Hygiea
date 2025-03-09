import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

// Data model for water quality measurements
class WaterQualityData {
  final double temperature;
  final double ph;
  final double turbidity;
  final double tds;

  WaterQualityData({
    required this.temperature,
    required this.ph,
    required this.turbidity,
    required this.tds,
  });

  factory WaterQualityData.fromMap(Map<dynamic, dynamic> map) {
    return WaterQualityData(
      temperature:
          double.tryParse(map['temperature']?.toString() ?? '0.0') ?? 0.0,
      ph: double.tryParse(map['ph']?.toString() ?? '0.0') ?? 0.0,
      turbidity: double.tryParse(map['turbidity']?.toString() ?? '0.0') ?? 0.0,
      tds: double.tryParse(map['tds']?.toString() ?? '0.0') ?? 0.0,
    );
  }

  factory WaterQualityData.empty() {
    return WaterQualityData(
      temperature: 0.0,
      ph: 0.0,
      turbidity: 0.0,
      tds: 0.0,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const HygieaApp());
}

class HygieaApp extends StatelessWidget {
  const HygieaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hygiea - Water Quality Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HygieaHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HygieaHome extends StatefulWidget {
  const HygieaHome({Key? key}) : super(key: key);

  @override
  _HygieaHomeState createState() => _HygieaHomeState();
}

class _HygieaHomeState extends State<HygieaHome> {
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref().child('HygieaData');

  bool _isLoading = true;
  String _error = '';
  WaterQualityData _data = WaterQualityData.empty();
  Timer? _refreshTimer;
  bool _isAutoRefreshEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        if (_isAutoRefreshEnabled) {
          _fetchLatestData();
        }
      },
    );
  }

  void _toggleAutoRefresh() {
    setState(() {
      _isAutoRefreshEnabled = !_isAutoRefreshEnabled;
      if (_isAutoRefreshEnabled) {
        _startAutoRefresh();
      } else {
        _refreshTimer?.cancel();
      }
    });
  }

  Future<void> _fetchLatestData() async {
    try {
      final snapshot = await _databaseRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map?;
        if (data != null) {
          setState(() {
            _data = WaterQualityData.fromMap(data);
            _error = '';
          });
        }
      }
    } catch (e) {
      print('Error fetching latest data: $e');
    }
  }

  Future<void> _initializeData() async {
    try {
      final snapshot = await _databaseRef.get();
      if (!snapshot.exists) {
        setState(() {
          _error = 'No data available';
          _isLoading = false;
        });
        return;
      }

      final data = snapshot.value as Map?;
      if (data != null) {
        setState(() {
          _data = WaterQualityData.fromMap(data);
          _isLoading = false;
          _error = '';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Initialization error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hygiea - Water Quality Monitor'),
        actions: [
          IconButton(
            icon: Icon(
              _isAutoRefreshEnabled ? Icons.sync : Icons.sync_disabled,
            ),
            onPressed: _toggleAutoRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLatestData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        SensorCard(
            title: 'Temperature',
            value: _data.temperature,
            unit: '°C',
            icon: Icons.thermostat,
            color: Colors.orange),
        SensorCard(
            title: 'pH Level',
            value: _data.ph,
            unit: '',
            icon: Icons.science,
            color: Colors.blue),
        SensorCard(
            title: 'Turbidity',
            value: _data.turbidity,
            unit: 'NTU',
            icon: Icons.waves,
            color: Colors.brown),
        SensorCard(
            title: 'TDS',
            value: _data.tds,
            unit: 'ppm',
            icon: Icons.opacity,
            color: Colors.purple),
      ],
    );
  }
}

class SensorCard extends StatelessWidget {
  final String title;
  final double value;
  final String unit;
  final IconData icon;
  final Color color;

  const SensorCard({
    Key? key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 36),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${value.toStringAsFixed(2)} $unit',
            style: TextStyle(color: color, fontSize: 18)),
      ),
    );
  }
}
