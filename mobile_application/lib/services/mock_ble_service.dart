import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/sensor_data.dart';

/// Mock BLE service for testing the app without hardware
class MockBleService extends ChangeNotifier {
  final StreamController<SensorData> _sensorDataController = StreamController<SensorData>.broadcast();
  Timer? _dataTimer;
  final Random _random = Random();
  
  // Simulated sensor values with realistic ranges and patterns
  double _baseCo2 = 400.0;
  double _baseHumidity = 50.0;
  double _baseTemperature = 22.0;
  int _alertState = 0;
  
  // Stream for external consumption
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;

  @override
  void dispose() {
    stopMockData();
    _sensorDataController.close();
    super.dispose();
  }

  /// Start generating mock sensor data
  void startMockData() {
    if (_dataTimer != null) return;
    
    print('Starting mock sensor data generation');
    
    // Generate data every 2 seconds
    _dataTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _generateMockData();
    });
    
    // Generate initial data point
    _generateMockData();
  }

  /// Stop generating mock sensor data
  void stopMockData() {
    _dataTimer?.cancel();
    _dataTimer = null;
    print('Stopped mock sensor data generation');
  }

  /// Generate a realistic mock sensor data point
  void _generateMockData() {
    // Simulate gradual changes and occasional spikes
    _simulateRealisticChanges();
    
    final sensorData = SensorData(
      co2: _baseCo2 + (_random.nextDouble() - 0.5) * 20, // ±10 ppm noise
      humidity: (_baseHumidity + (_random.nextDouble() - 0.5) * 10).clamp(0, 100), // ±5% noise
      temperature: _baseTemperature + (_random.nextDouble() - 0.5) * 2, // ±1°C noise
      alert: _alertState,
      timestamp: DateTime.now(),
    );
    
    _sensorDataController.add(sensorData);
  }

  /// Simulate realistic changes in sensor values over time
  void _simulateRealisticChanges() {
    // CO₂ levels: simulate breathing patterns and air quality changes
    if (_random.nextDouble() < 0.1) {
      // Occasional spike (someone breathing nearby or poor ventilation)
      _baseCo2 += _random.nextDouble() * 300 + 100; // +100 to +400 ppm spike
    } else if (_baseCo2 > 450) {
      // Gradual decrease when air quality improves
      _baseCo2 -= _random.nextDouble() * 50 + 10; // -10 to -60 ppm
    } else {
      // Small random walk
      _baseCo2 += (_random.nextDouble() - 0.5) * 40; // ±20 ppm
    }
    
    // Keep CO₂ in realistic indoor range (350-2000 ppm)
    _baseCo2 = _baseCo2.clamp(350, 2000);
    
    // Humidity: simulate seasonal and daily variations
    if (_random.nextDouble() < 0.05) {
      // Occasional humidity change (weather, HVAC)
      _baseHumidity += (_random.nextDouble() - 0.5) * 30; // ±15% change
    } else {
      // Gradual drift
      _baseHumidity += (_random.nextDouble() - 0.5) * 4; // ±2% drift
    }
    
    // Keep humidity in realistic indoor range (20-80%)
    _baseHumidity = _baseHumidity.clamp(20, 80);
    
    // Temperature: simulate HVAC cycles and thermal mass
    if (_random.nextDouble() < 0.03) {
      // HVAC system turns on/off
      final targetTemp = 20 + _random.nextDouble() * 8; // 20-28°C target range
      _baseTemperature += (targetTemp - _baseTemperature) * 0.2; // Move 20% toward target
    } else {
      // Small thermal variations
      _baseTemperature += (_random.nextDouble() - 0.5) * 1; // ±0.5°C
    }
    
    // Keep temperature in realistic indoor range (18-30°C)
    _baseTemperature = _baseTemperature.clamp(18, 30);
    
    // Alert logic based on CO₂ levels (mimicking real device behavior)
    if (_baseCo2 > 1500) {
      _alertState = 2; // Critical
    } else if (_baseCo2 > 1000) {
      _alertState = 1; // Warning
    } else {
      _alertState = 0; // Normal
    }
  }

  /// Simulate extreme values for testing UI behavior
  void simulateExtremeValues() {
    _baseCo2 = 1800 + _random.nextDouble() * 200; // High CO₂
    _baseHumidity = 15 + _random.nextDouble() * 10; // Low humidity
    _baseTemperature = 28 + _random.nextDouble() * 5; // High temperature
    _alertState = 2; // Critical alert
    
    _generateMockData();
  }

  /// Simulate normal values for testing UI behavior
  void simulateNormalValues() {
    _baseCo2 = 400 + _random.nextDouble() * 200; // Normal CO₂
    _baseHumidity = 45 + _random.nextDouble() * 20; // Comfortable humidity
    _baseTemperature = 20 + _random.nextDouble() * 6; // Comfortable temperature
    _alertState = 0; // Normal
    
    _generateMockData();
  }

  /// Mock control command responses
  Future<bool> mockWriteControl(Map<String, dynamic> command) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 100 + _random.nextInt(200)));
    
    print('Mock device received control command: $command');
    
    // Simulate occasional failures (5% chance)
    if (_random.nextDouble() < 0.05) {
      print('Mock device: Command failed');
      return false;
    }
    
    // Simulate device responses to commands
    switch (command['cmd']) {
      case 'mute':
        print('Mock device: ${command['value'] ? 'Muted' : 'Unmuted'}');
        break;
      case 'volume':
        print('Mock device: Volume set to ${command['value']}');
        break;
      case 'power':
        if (command['value'] == 'off') {
          print('Mock device: Powering off...');
          stopMockData();
        }
        break;
    }
    
    return true;
  }

  /// Get mock device information
  Map<String, dynamic> getMockDeviceInfo() {
    return {
      'name': 'RespirationMonitor (Mock)',
      'id': 'mock-device-12345',
      'rssi': -45 + _random.nextInt(20), // Good signal strength
      'firmwareVersion': '1.2.3',
      'batteryLevel': 75 + _random.nextInt(25), // 75-100%
    };
  }

  /// Simulate different air quality scenarios for testing
  void simulateScenario(String scenario) {
    switch (scenario) {
      case 'meeting_room':
        // Crowded meeting room with poor ventilation
        _baseCo2 = 1200 + _random.nextDouble() * 400;
        _baseHumidity = 60 + _random.nextDouble() * 15;
        _baseTemperature = 24 + _random.nextDouble() * 3;
        break;
      case 'fresh_air':
        // Well-ventilated space with fresh air
        _baseCo2 = 350 + _random.nextDouble() * 100;
        _baseHumidity = 40 + _random.nextDouble() * 20;
        _baseTemperature = 21 + _random.nextDouble() * 4;
        break;
      case 'sleeping_bedroom':
        // Bedroom overnight with closed windows
        _baseCo2 = 800 + _random.nextDouble() * 600;
        _baseHumidity = 50 + _random.nextDouble() * 20;
        _baseTemperature = 19 + _random.nextDouble() * 3;
        break;
      case 'kitchen_cooking':
        // Kitchen during cooking
        _baseCo2 = 600 + _random.nextDouble() * 400;
        _baseHumidity = 70 + _random.nextDouble() * 15;
        _baseTemperature = 25 + _random.nextDouble() * 6;
        break;
      default:
        // Default to normal office environment
        _baseCo2 = 450 + _random.nextDouble() * 300;
        _baseHumidity = 45 + _random.nextDouble() * 25;
        _baseTemperature = 22 + _random.nextDouble() * 4;
        break;
    }
    
    _generateMockData();
  }
}
