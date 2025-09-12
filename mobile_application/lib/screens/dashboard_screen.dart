import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sensor_data.dart';
import '../services/ble_service.dart';
import '../services/mock_ble_service.dart';
import '../widgets/charts.dart';
import 'settings_screen.dart';
import 'scan_screen.dart';

/// Main dashboard screen showing real-time sensor data and charts
class DashboardScreen extends StatefulWidget {
  final bool mockMode;
  
  const DashboardScreen({super.key, this.mockMode = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Queue<SensorData> _sensorDataHistory = Queue<SensorData>();
  static const int maxHistoryLength = 300; // Keep last 300 samples
  static const int chartDisplayLength = 60; // Show last 60 in sparklines
  
  SensorData? _latestData;
  String _selectedChartMetric = 'co2';
  StreamSubscription<SensorData>? _sensorDataSubscription;
  StreamSubscription<BleConnectionState>? _connectionStateSubscription;
  MockBleService? _mockService;
  
  // Connection state
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  String? _connectedDeviceName;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  @override
  void dispose() {
    _sensorDataSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _mockService?.dispose();
    super.dispose();
  }

  void _initializeDashboard() {
    if (widget.mockMode) {
      _initializeMockMode();
    } else {
      _initializeRealMode();
    }
  }

  void _initializeMockMode() {
    _mockService = MockBleService();
    _connectionState = BleConnectionState.connected;
    _connectedDeviceName = 'Mock Device';
    
    _sensorDataSubscription = _mockService!.sensorDataStream.listen((data) {
      if (mounted) {
        _addSensorData(data);
      }
    });
    
    _mockService!.startMockData();
  }

  void _initializeRealMode() {
    final bleService = context.read<BleService>();
    
    // Listen to sensor data
    _sensorDataSubscription = bleService.sensorDataStream.listen((data) {
      if (mounted) {
        _addSensorData(data);
      }
    });
    
    // Listen to connection state changes
    _connectionStateSubscription = bleService.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
          if (state == BleConnectionState.disconnected) {
            _connectedDeviceName = null;
          } else if (state == BleConnectionState.connected) {
            _connectedDeviceName = bleService.connectedDeviceId?.substring(0, 8);
          }
        });
        
        // Handle disconnection
        if (state == BleConnectionState.disconnected) {
          _showDisconnectedDialog();
        }
      }
    });
    
    // Get current connection state
    _connectionState = bleService.connectionState;
    _connectedDeviceName = bleService.connectedDeviceId?.substring(0, 8);
  }

  void _addSensorData(SensorData data) {
    setState(() {
      _latestData = data;
      _sensorDataHistory.addLast(data);
      
      // Keep only the last maxHistoryLength samples
      while (_sensorDataHistory.length > maxHistoryLength) {
        _sensorDataHistory.removeFirst();
      }
    });
  }

  void _showDisconnectedDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Device Disconnected'),
            ],
          ),
          content: const Text(
            'The RespirationMonitor device has been disconnected. '
            'The app will attempt to reconnect automatically.'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const ScanScreen(),
                  ),
                );
              },
              child: const Text('Back to Scan'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Wait for Reconnect'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _disconnect() async {
    if (widget.mockMode) {
      _mockService?.dispose();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ScanScreen(),
        ),
      );
    } else {
      final bleService = context.read<BleService>();
      await bleService.disconnect();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const ScanScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayData = _sensorDataHistory.length > chartDisplayLength 
        ? _sensorDataHistory.toList().sublist(_sensorDataHistory.length - chartDisplayLength)
        : _sensorDataHistory.toList();
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.mockMode ? 'Dashboard (Mock)' : 'Dashboard'),
            if (_connectedDeviceName != null)
              Text(
                'Connected: $_connectedDeviceName',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          // Connection status indicator
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getConnectionColor(),
            ),
          ),
          // Settings button
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(mockMode: widget.mockMode),
                ),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
        automaticallyImplyLeading: false, // Remove back button since we handle navigation
      ),
      body: _latestData == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for sensor data...',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.mockMode 
                        ? 'Mock data will appear shortly'
                        : 'Make sure your device is connected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                // Refresh action - could be used to reset data or reconnect
                if (!widget.mockMode) {
                  final bleService = context.read<BleService>();
                  if (bleService.connectionState != BleConnectionState.connected) {
                    await _disconnect();
                  }
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status card with alert indicator
                    Card(
                      color: Color(_latestData!.alertColor).withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(_latestData!.alertColor),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Air Quality: ${_latestData!.alertDescription}',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Last updated: ${_formatTimestamp(_latestData!.timestamp)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Metric cards
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 1,
                      childAspectRatio: 2.5,
                      mainAxisSpacing: 12,
                      children: [
                        MetricCard(
                          title: 'CO₂ Level',
                          value: _latestData!.co2,
                          unit: 'ppm',
                          data: displayData,
                          metric: 'co2',
                          color: const Color(0xFF2196F3),
                          icon: Icons.co2,
                        ),
                        MetricCard(
                          title: 'Humidity',
                          value: _latestData!.humidity,
                          unit: '%',
                          data: displayData,
                          metric: 'humidity',
                          color: const Color(0xFF00BCD4),
                          icon: Icons.water_drop,
                        ),
                        MetricCard(
                          title: 'Temperature',
                          value: _latestData!.temperature,
                          unit: '°C',
                          data: displayData,
                          metric: 'temperature',
                          color: const Color(0xFFFF5722),
                          icon: Icons.thermostat,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Time series chart
                    TimeSeriesChart(
                      data: _sensorDataHistory.toList(),
                      selectedMetric: _selectedChartMetric,
                      onMetricChanged: (metric) {
                        setState(() {
                          _selectedChartMetric = metric;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Disconnect button
                    ElevatedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.bluetooth_disabled),
                      label: const Text('Disconnect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.errorContainer,
                        foregroundColor: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Color _getConnectionColor() {
    switch (_connectionState) {
      case BleConnectionState.connected:
        return Colors.green;
      case BleConnectionState.connecting:
        return Colors.orange;
      case BleConnectionState.disconnecting:
        return Colors.orange;
      case BleConnectionState.disconnected:
        return Colors.red;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
