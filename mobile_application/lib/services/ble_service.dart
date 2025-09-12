import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sensor_data.dart';

/// BLE service for communicating with RespirationMonitor ESP32 devices
class BleService extends ChangeNotifier {
  static const String targetDeviceName = 'RespirationMonitor';
  static const String serviceUuid = '12345678-1234-1234-1234-123456789abc';
  static const String dataCharacteristicUuid = '87654321-4321-4321-4321-cba987654321';
  static const String controlCharacteristicUuid = '11111111-2222-3333-4444-555555555555';
  static const String lastConnectedDeviceKey = 'last_connected_device';
  
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final StreamController<SensorData> _sensorDataController = StreamController<SensorData>.broadcast();
  final StreamController<BleConnectionState> _connectionStateController = StreamController<BleConnectionState>.broadcast();
  final StreamController<DiscoveredDevice> _scanResultsController = StreamController<DiscoveredDevice>.broadcast();

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;
  QualifiedCharacteristic? _dataCharacteristic;
  QualifiedCharacteristic? _controlCharacteristic;
  
  String? _connectedDeviceId;
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  bool _isScanning = false;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 3;
  Timer? _reconnectTimer;
  
  // Streams for external consumption
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;
  Stream<BleConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<DiscoveredDevice> get scanResults => _scanResultsController.stream;
  
  // Getters
  bool get isScanning => _isScanning;
  BleConnectionState get connectionState => _connectionState;
  String? get connectedDeviceId => _connectedDeviceId;

  @override
  void dispose() {
    stopScan();
    _disconnect();
    _sensorDataController.close();
    _connectionStateController.close();
    _scanResultsController.close();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  /// Initialize BLE and request necessary permissions
  Future<bool> initialize() async {
    try {
      // Check BLE status
      final bleStatus = await _ble.status;
      print('BLE Status: $bleStatus');
      
      if (bleStatus != BleStatus.ready) {
        print('BLE not ready: $bleStatus');
        return false;
      }

      // Request permissions
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        print('BLE permissions not granted');
        return false;
      }

      print('BLE service initialized successfully');
      return true;
    } catch (e) {
      print('BLE initialization failed: $e');
      return false;
    }
  }

  /// Request necessary BLE and location permissions
  Future<bool> _requestPermissions() async {
    final permissionsToRequest = <Permission>[];

    // Location permission (required for BLE scanning on Android)
    if (Platform.isAndroid) {
      permissionsToRequest.add(Permission.location);
    }

    // Android 12+ BLE permissions
    if (Platform.isAndroid) {
      permissionsToRequest.addAll([
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ]);
    }

    if (permissionsToRequest.isEmpty) return true;

    final statuses = await permissionsToRequest.request();
    
    // Check if all required permissions are granted
    for (final permission in permissionsToRequest) {
      final status = statuses[permission];
      if (status != PermissionStatus.granted) {
        print('Permission $permission not granted: $status');
        
        // For critical permissions, return false
        if (permission == Permission.bluetoothScan || 
            permission == Permission.bluetoothConnect) {
          return false;
        }
      }
    }

    return true;
  }

  /// Start scanning for RespirationMonitor devices
  Future<void> startScan() async {
    if (_isScanning) return;

    try {
      _isScanning = true;
      notifyListeners();

      print('Starting BLE scan for $targetDeviceName devices...');
      
      _scanSubscription = _ble.scanForDevices(
        withServices: [Uuid.parse(serviceUuid)],
        scanMode: ScanMode.lowLatency,
        requireLocationServicesEnabled: false,
      ).listen(
        (device) {
          // Filter devices by name or service UUID
          if (device.name == targetDeviceName || 
              device.serviceUuids.contains(Uuid.parse(serviceUuid))) {
            print('Found device: ${device.name} (${device.id})');
            _scanResultsController.add(device);
          }
        },
        onError: (error) {
          print('Scan error: $error');
        },
      );

      // Stop scanning after 30 seconds
      Timer(const Duration(seconds: 30), () {
        if (_isScanning) {
          stopScan();
        }
      });
    } catch (e) {
      print('Failed to start scan: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop BLE scanning
  void stopScan() {
    if (!_isScanning) return;

    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    notifyListeners();
    print('BLE scan stopped');
  }

  /// Connect to a discovered BLE device
  Future<bool> connectToDevice(String deviceId) async {
    if (_connectionState == BleConnectionState.connecting) {
      print('Already connecting to a device');
      return false;
    }

    try {
      stopScan();
      _updateConnectionState(BleConnectionState.connecting);
      _reconnectAttempts = 0;

      print('Connecting to device: $deviceId');
      
      _connectionSubscription = _ble.connectToDevice(
        id: deviceId,
        connectionTimeout: const Duration(seconds: 10),
      ).listen(
        (connectionState) async {
          print('Connection state update: ${connectionState.connectionState}');
          
          switch (connectionState.connectionState) {
            case DeviceConnectionState.connecting:
              _updateConnectionState(BleConnectionState.connecting);
              break;
            case DeviceConnectionState.connected:
              _connectedDeviceId = deviceId;
              await _setupCharacteristics(deviceId);
              _saveLastConnectedDevice(deviceId);
              _updateConnectionState(BleConnectionState.connected);
              _reconnectAttempts = 0; // Reset reconnect attempts on successful connection
              break;
            case DeviceConnectionState.disconnecting:
              _updateConnectionState(BleConnectionState.disconnecting);
              break;
            case DeviceConnectionState.disconnected:
              _connectedDeviceId = null;
              _updateConnectionState(BleConnectionState.disconnected);
              _cleanup();
              
              // Auto-reconnect logic with exponential backoff
              if (_reconnectAttempts < maxReconnectAttempts) {
                _scheduleReconnect(deviceId);
              }
              break;
          }
        },
        onError: (error) {
          print('Connection error: $error');
          _updateConnectionState(BleConnectionState.disconnected);
          _cleanup();
        },
      );

      return true;
    } catch (e) {
      print('Failed to connect: $e');
      _updateConnectionState(BleConnectionState.disconnected);
      return false;
    }
  }

  /// Schedule automatic reconnection with exponential backoff
  void _scheduleReconnect(String deviceId) {
    _reconnectAttempts++;
    final delay = Duration(seconds: pow(2, _reconnectAttempts - 1).toInt() * 2); // 2, 4, 8 seconds
    
    print('Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds} seconds');
    
    _reconnectTimer = Timer(delay, () {
      if (_connectionState == BleConnectionState.disconnected) {
        print('Auto-reconnecting to device: $deviceId');
        connectToDevice(deviceId);
      }
    });
  }

  /// Setup BLE characteristics after connection
  Future<void> _setupCharacteristics(String deviceId) async {
    try {
      final serviceUuidParsed = Uuid.parse(serviceUuid);
      
      _dataCharacteristic = QualifiedCharacteristic(
        serviceId: serviceUuidParsed,
        characteristicId: Uuid.parse(dataCharacteristicUuid),
        deviceId: deviceId,
      );

      _controlCharacteristic = QualifiedCharacteristic(
        serviceId: serviceUuidParsed,
        characteristicId: Uuid.parse(controlCharacteristicUuid),
        deviceId: deviceId,
      );

      // Subscribe to data characteristic notifications
      _characteristicSubscription = _ble.subscribeToCharacteristic(_dataCharacteristic!).listen(
        (data) {
          _handleNotificationData(data);
        },
        onError: (error) {
          print('Characteristic subscription error: $error');
        },
      );

      print('BLE characteristics setup complete');
    } catch (e) {
      print('Failed to setup characteristics: $e');
      throw e;
    }
  }

  /// Handle incoming notification data from the ESP32
  void _handleNotificationData(List<int> data) {
    try {
      final sensorData = SensorDataParser.parseFromBytes(data);
      if (sensorData != null) {
        _sensorDataController.add(sensorData);
        print('Received sensor data: $sensorData');
      } else {
        print('Failed to parse sensor data from notification');
      }
    } catch (e) {
      print('Error handling notification data: $e');
    }
  }

  /// Write a control command to the ESP32
  Future<bool> writeControlCommand(Map<String, dynamic> command) async {
    if (_controlCharacteristic == null || _connectionState != BleConnectionState.connected) {
      print('Cannot write command: not connected or characteristic not available');
      return false;
    }

    try {
      final jsonString = jsonEncode(command);
      final bytes = utf8.encode(jsonString);
      
      print('Writing control command: $jsonString');
      
      await _ble.writeCharacteristicWithResponse(
        _controlCharacteristic!, 
        value: bytes,
      );
      
      print('Control command sent successfully');
      return true;
    } catch (e) {
      print('Failed to write control command: $e');
      return false;
    }
  }

  /// Send mute/unmute command
  Future<bool> sendMuteCommand(bool mute) async {
    return await writeControlCommand({
      'cmd': 'mute',
      'value': mute,
    });
  }

  /// Send volume control command (0-100)
  Future<bool> sendVolumeCommand(int volume) async {
    if (volume < 0 || volume > 100) {
      print('Invalid volume value: $volume');
      return false;
    }
    
    return await writeControlCommand({
      'cmd': 'volume',
      'value': volume,
    });
  }

  /// Send power off command
  Future<bool> sendPowerOffCommand() async {
    return await writeControlCommand({
      'cmd': 'power',
      'value': 'off',
    });
  }

  /// Disconnect from the current device
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = maxReconnectAttempts; // Prevent auto-reconnect
    await _disconnect();
  }

  /// Internal disconnect method
  Future<void> _disconnect() async {
    if (_connectionState == BleConnectionState.disconnected) return;

    print('Disconnecting from device');
    
    _cleanup();
    _connectedDeviceId = null;
    _updateConnectionState(BleConnectionState.disconnected);
  }

  /// Clean up subscriptions and characteristics
  void _cleanup() {
    _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _dataCharacteristic = null;
    _controlCharacteristic = null;
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(BleConnectionState newState) {
    _connectionState = newState;
    _connectionStateController.add(newState);
    notifyListeners();
  }

  /// Save the last connected device ID to SharedPreferences
  Future<void> _saveLastConnectedDevice(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(lastConnectedDeviceKey, deviceId);
    } catch (e) {
      print('Failed to save last connected device: $e');
    }
  }

  /// Get the last connected device ID from SharedPreferences
  Future<String?> getLastConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(lastConnectedDeviceKey);
    } catch (e) {
      print('Failed to get last connected device: $e');
      return null;
    }
  }

  /// Clear the saved last connected device
  Future<void> clearLastConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(lastConnectedDeviceKey);
    } catch (e) {
      print('Failed to clear last connected device: $e');
    }
  }
}

/// Enum representing BLE connection states
enum BleConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

extension BleConnectionStateExtension on BleConnectionState {
  String get displayName {
    switch (this) {
      case BleConnectionState.disconnected:
        return 'Disconnected';
      case BleConnectionState.connecting:
        return 'Connecting';
      case BleConnectionState.connected:
        return 'Connected';
      case BleConnectionState.disconnecting:
        return 'Disconnecting';
    }
  }
}
