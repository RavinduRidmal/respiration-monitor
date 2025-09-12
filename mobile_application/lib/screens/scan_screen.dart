import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:provider/provider.dart';

import '../services/ble_service.dart';
import 'dashboard_screen.dart';

/// Screen for scanning and connecting to RespirationMonitor devices
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<DiscoveredDevice> _discoveredDevices = [];
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<BleConnectionState>? _connectionSubscription;
  String? _connectingDeviceId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeBle();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeBle() async {
    final bleService = context.read<BleService>();
    
    // Listen to connection state changes
    _connectionSubscription = bleService.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          if (state == BleConnectionState.connected) {
            _connectingDeviceId = null;
            _errorMessage = null;
            // Navigate to dashboard
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const DashboardScreen(),
              ),
            );
          } else if (state == BleConnectionState.disconnected && _connectingDeviceId != null) {
            _connectingDeviceId = null;
            _errorMessage = 'Failed to connect to device';
          }
        });
      }
    });

    // Initialize BLE
    final success = await bleService.initialize();
    if (!success && mounted) {
      setState(() {
        _errorMessage = 'Failed to initialize Bluetooth. Please check permissions and try again.';
      });
    }

    // Try to auto-connect to last connected device
    final lastDevice = await bleService.getLastConnectedDevice();
    if (lastDevice != null && mounted) {
      _showAutoReconnectDialog(lastDevice);
    }
  }

  void _showAutoReconnectDialog(String deviceId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Auto Reconnect'),
          content: Text('Would you like to reconnect to the last connected device?\n\nDevice ID: ${deviceId.substring(0, 8)}...'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _connectToDevice(deviceId);
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  void _startScan() {
    setState(() {
      _discoveredDevices.clear();
      _errorMessage = null;
    });

    final bleService = context.read<BleService>();
    
    // Listen to scan results
    _scanSubscription?.cancel();
    _scanSubscription = bleService.scanResults.listen((device) {
      if (mounted) {
        setState(() {
          // Avoid duplicates
          final existingIndex = _discoveredDevices.indexWhere((d) => d.id == device.id);
          if (existingIndex >= 0) {
            _discoveredDevices[existingIndex] = device; // Update RSSI
          } else {
            _discoveredDevices.add(device);
          }
        });
      }
    });

    bleService.startScan();
  }

  void _stopScan() {
    final bleService = context.read<BleService>();
    bleService.stopScan();
    _scanSubscription?.cancel();
  }

  Future<void> _connectToDevice(String deviceId) async {
    setState(() {
      _connectingDeviceId = deviceId;
      _errorMessage = null;
    });

    _stopScan();
    
    final bleService = context.read<BleService>();
    final success = await bleService.connectToDevice(deviceId);
    
    if (!success && mounted) {
      setState(() {
        _connectingDeviceId = null;
        _errorMessage = 'Failed to start connection process';
      });
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About Respiration Monitor'),
          content: const Text(
            'This app connects to RespirationMonitor devices via Bluetooth to monitor air quality in real-time. '
            'The device measures CO₂ levels, humidity, and temperature, providing alerts when air quality becomes poor.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showMockModeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Mock Mode'),
          content: const Text(
            'Mock mode allows you to test the app without a physical RespirationMonitor device. '
            'Simulated sensor data will be generated for demonstration purposes.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to dashboard with mock mode
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const DashboardScreen(mockMode: true),
                  ),
                );
              },
              child: const Text('Enable Mock Mode'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bleService = context.watch<BleService>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Respiration Monitors'),
        actions: [
          IconButton(
            onPressed: _showHelpDialog,
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Control buttons
            Row(
              children: [
                Expanded(
                  child: bleService.isScanning
                      ? ElevatedButton.icon(
                          onPressed: _stopScan,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Scan'),
                        )
                      : FilledButton.icon(
                          onPressed: _startScan,
                          icon: const Icon(Icons.bluetooth_searching),
                          label: const Text('Scan for Devices'),
                        ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _showMockModeDialog,
                  icon: const Icon(Icons.developer_mode),
                  label: const Text('Mock Mode'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Status message
            if (_errorMessage != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (bleService.isScanning)
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Scanning for RespirationMonitor devices...',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_discoveredDevices.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bluetooth_disabled,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No devices found',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Make sure your RespirationMonitor device is powered on and nearby.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Device list
            if (_discoveredDevices.isNotEmpty) ...[
              Text(
                'Found Devices',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
            ],
            
            Expanded(
              child: ListView.builder(
                itemCount: _discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = _discoveredDevices[index];
                  final isConnecting = _connectingDeviceId == device.id;
                  
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.sensors,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        device.name.isEmpty ? 'Unknown Device' : device.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID: ${device.id.substring(0, 8)}...',
                            style: theme.textTheme.bodySmall,
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.signal_cellular_alt,
                                size: 16,
                                color: _getRssiColor(device.rssi, theme),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${device.rssi} dBm',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _getRssiColor(device.rssi, theme),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: isConnecting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : FilledButton(
                              onPressed: () => _connectToDevice(device.id),
                              child: const Text('Connect'),
                            ),
                      onTap: isConnecting ? null : () => _connectToDevice(device.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRssiColor(int rssi, ThemeData theme) {
    if (rssi >= -50) {
      return Colors.green;
    } else if (rssi >= -70) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
