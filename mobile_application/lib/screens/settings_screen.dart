import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ble_service.dart';
import '../services/mock_ble_service.dart';

/// Settings screen for device control commands
class SettingsScreen extends StatefulWidget {
  final bool mockMode;
  
  const SettingsScreen({super.key, this.mockMode = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isMuted = false;
  double _volumeLevel = 50.0;
  String? _lastCommandResult;
  DateTime? _lastCommandTime;
  bool _isCommandInProgress = false;
  Timer? _volumeDebounceTimer;
  
  // Mock service reference for mock mode
  MockBleService? _mockService;

  @override
  void initState() {
    super.initState();
    if (widget.mockMode) {
      // In mock mode, create a reference to mock service for control commands
      // Note: In a real app, this would be injected or managed differently
    }
  }

  @override
  void dispose() {
    _volumeDebounceTimer?.cancel();
    super.dispose();
  }

  /// Send a control command to the device
  Future<void> _sendControlCommand(Map<String, dynamic> command, String description) async {
    if (_isCommandInProgress) return;
    
    setState(() {
      _isCommandInProgress = true;
      _lastCommandResult = null;
    });

    try {
      bool success;
      if (widget.mockMode) {
        // Mock mode: simulate command response
        _mockService ??= MockBleService();
        success = await _mockService!.mockWriteControl(command);
      } else {
        // Real mode: send to BLE service
        final bleService = context.read<BleService>();
        success = await bleService.writeControlCommand(command);
      }

      setState(() {
        _lastCommandResult = success 
            ? '$description command sent successfully'
            : '$description command failed';
        _lastCommandTime = DateTime.now();
        _isCommandInProgress = false;
      });

      // Show snackbar feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_lastCommandResult!),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _lastCommandResult = 'Error: $e';
        _lastCommandTime = DateTime.now();
        _isCommandInProgress = false;
      });
    }
  }

  /// Handle mute toggle
  Future<void> _handleMuteToggle(bool value) async {
    await _sendControlCommand({
      'cmd': 'mute',
      'value': value,
    }, value ? 'Mute' : 'Unmute');
    
    setState(() {
      _isMuted = value;
    });
  }

  /// Handle volume change with debouncing
  void _handleVolumeChange(double value) {
    setState(() {
      _volumeLevel = value;
    });

    // Debounce volume changes to avoid flooding the device
    _volumeDebounceTimer?.cancel();
    _volumeDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _sendControlCommand({
        'cmd': 'volume',
        'value': value.round(),
      }, 'Volume');
    });
  }

  /// Show power off confirmation dialog
  void _showPowerOffDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.power_settings_new, color: Colors.red),
              SizedBox(width: 8),
              Text('Power Off Device'),
            ],
          ),
          content: const Text(
            'Are you sure you want to power off the RespirationMonitor device? '
            'You will need to manually power it back on to reconnect.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handlePowerOff();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Power Off'),
            ),
          ],
        );
      },
    );
  }

  /// Handle power off command
  Future<void> _handlePowerOff() async {
    await _sendControlCommand({
      'cmd': 'power',
      'value': 'off',
    }, 'Power off');
    
    // After power off, navigate back to scan screen
    if (mounted) {
      // Add a delay to allow the command to be sent
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
  }

  /// Show help dialog about device controls
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Device Controls Help'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mute Device',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Enables or disables audio alerts from the device.'),
                SizedBox(height: 12),
                Text(
                  'Volume Control',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Adjusts the volume of audio alerts (0-100).'),
                SizedBox(height: 12),
                Text(
                  'Power Off',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Safely shuts down the device. You will need to manually power it back on.'),
                SizedBox(height: 12),
                Text(
                  'Note: Commands may take a few seconds to be processed by the device.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mockMode ? 'Settings (Mock)' : 'Device Settings'),
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
            // Device mute toggle
            Card(
              child: SwitchListTile(
                title: const Text('Mute Device'),
                subtitle: Text(_isMuted 
                    ? 'Audio alerts are disabled' 
                    : 'Audio alerts are enabled'),
                value: _isMuted,
                onChanged: _isCommandInProgress ? null : _handleMuteToggle,
                secondary: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: _isMuted ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Volume control
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.volume_up,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Volume Level',
                          style: theme.textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_volumeLevel.round()}%',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _volumeLevel,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      onChanged: _isCommandInProgress ? null : _handleVolumeChange,
                    ),
                    Text(
                      'Adjust the volume of audio alerts (0-100)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Power off button
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.power_settings_new,
                  color: Colors.red,
                ),
                title: const Text('Power Off Device'),
                subtitle: const Text('Safely shut down the RespirationMonitor'),
                onTap: _isCommandInProgress ? null : _showPowerOffDialog,
                trailing: _isCommandInProgress
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Command status
            if (_lastCommandResult != null)
              Card(
                color: _lastCommandResult!.contains('successfully')
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _lastCommandResult!.contains('successfully')
                                ? Icons.check_circle
                                : Icons.error,
                            color: _lastCommandResult!.contains('successfully')
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Last Command',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: _lastCommandResult!.contains('successfully')
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _lastCommandResult!,
                        style: TextStyle(
                          color: _lastCommandResult!.contains('successfully')
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      if (_lastCommandTime != null)
                        Text(
                          'At ${_lastCommandTime!.hour.toString().padLeft(2, '0')}:'
                          '${_lastCommandTime!.minute.toString().padLeft(2, '0')}:'
                          '${_lastCommandTime!.second.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: (_lastCommandResult!.contains('successfully')
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onErrorContainer)
                                .withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            
            const Spacer(),
            
            // Command in progress indicator
            if (_isCommandInProgress)
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Sending command...'),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Mock mode testing buttons (only in mock mode)
            if (widget.mockMode) ...[
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Mock Mode Testing',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      _mockService ??= MockBleService();
                      _mockService!.simulateExtremeValues();
                    },
                    child: const Text('Extreme Values'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      _mockService ??= MockBleService();
                      _mockService!.simulateNormalValues();
                    },
                    child: const Text('Normal Values'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
