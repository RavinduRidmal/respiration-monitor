import 'dart:convert';

/// Represents sensor data received from the ESP32 BLE peripheral
class SensorData {
  final double co2;
  final double humidity;
  final double temperature;
  final int alert;
  final DateTime timestamp;

  SensorData({
    required this.co2,
    required this.humidity,
    required this.temperature,
    required this.alert,
    required this.timestamp,
  });

  /// Creates a SensorData instance from a JSON map
  /// 
  /// Validates all fields and provides safe defaults where needed.
  /// Throws FormatException for invalid or missing required fields.
  factory SensorData.fromJson(Map<String, dynamic> json) {
    try {
      // Validate and convert CO₂ reading (must be non-negative)
      final co2Value = _parseDouble(json['co2'], 'co2');
      if (co2Value < 0) {
        throw FormatException('CO₂ value cannot be negative: $co2Value');
      }

      // Validate and convert humidity (should be 0-100%)
      final humidityValue = _parseDouble(json['humidity'], 'humidity');
      if (humidityValue < 0 || humidityValue > 100) {
        throw FormatException('Humidity value out of range: $humidityValue');
      }

      // Temperature can be negative (e.g., below freezing)
      final temperatureValue = _parseDouble(json['temperature'], 'temperature');

      // Alert code validation (0 = no alert, 1 = warn, 2 = critical)
      final alertValue = json['alert'] is num ? (json['alert'] as num).toInt() : 0;
      if (alertValue < 0 || alertValue > 2) {
        throw FormatException('Alert value out of range: $alertValue');
      }

      // Parse timestamp - use current time as fallback
      DateTime timestampValue;
      if (json['timestamp'] != null) {
        final timestampMs = (json['timestamp'] as num).toInt();
        timestampValue = DateTime.fromMillisecondsSinceEpoch(timestampMs);
      } else {
        timestampValue = DateTime.now();
      }

      return SensorData(
        co2: co2Value,
        humidity: humidityValue,
        temperature: temperatureValue,
        alert: alertValue,
        timestamp: timestampValue,
      );
    } catch (e) {
      throw FormatException('Invalid sensor data JSON: $e');
    }
  }

  /// Helper method to safely parse double values from JSON
  static double _parseDouble(dynamic value, String fieldName) {
    if (value == null) {
      throw FormatException('Missing required field: $fieldName');
    }
    if (value is num) {
      return value.toDouble();
    }
    throw FormatException('Invalid type for field $fieldName: expected number, got ${value.runtimeType}');
  }

  /// Converts the sensor data to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'co2': co2,
      'humidity': humidity,
      'temperature': temperature,
      'alert': alert,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// Returns a formatted string representation of the sensor data
  @override
  String toString() {
    return 'SensorData(co2: ${co2.toStringAsFixed(1)} ppm, '
           'humidity: ${humidity.toStringAsFixed(1)}%, '
           'temperature: ${temperature.toStringAsFixed(1)}°C, '
           'alert: $alert, '
           'timestamp: $timestamp)';
  }

  /// Returns the alert level as a descriptive string
  String get alertDescription {
    switch (alert) {
      case 0:
        return 'Normal';
      case 1:
        return 'Warning';
      case 2:
        return 'Critical';
      default:
        return 'Unknown';
    }
  }

  /// Returns the appropriate color for the alert level
  /// Used for UI indicators
  int get alertColor {
    switch (alert) {
      case 0:
        return 0xFF4CAF50; // Green
      case 1:
        return 0xFFFF9800; // Orange
      case 2:
        return 0xFFF44336; // Red
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  /// Creates a copy of this sensor data with optionally updated values
  SensorData copyWith({
    double? co2,
    double? humidity,
    double? temperature,
    int? alert,
    DateTime? timestamp,
  }) {
    return SensorData(
      co2: co2 ?? this.co2,
      humidity: humidity ?? this.humidity,
      temperature: temperature ?? this.temperature,
      alert: alert ?? this.alert,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SensorData &&
        other.co2 == co2 &&
        other.humidity == humidity &&
        other.temperature == temperature &&
        other.alert == alert &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return co2.hashCode ^
        humidity.hashCode ^
        temperature.hashCode ^
        alert.hashCode ^
        timestamp.hashCode;
  }
}

/// Utility class for parsing JSON strings to SensorData
class SensorDataParser {
  /// Parses a UTF-8 JSON string to a SensorData object
  /// 
  /// Returns null if the JSON is malformed or invalid.
  /// This is the main entry point for parsing BLE notification data.
  static SensorData? parseFromString(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return SensorData.fromJson(json);
    } catch (e) {
      // Log error in production app - for now just return null
      print('Failed to parse sensor data: $e');
      return null;
    }
  }

  /// Parses raw bytes (UTF-8 encoded JSON) to a SensorData object
  static SensorData? parseFromBytes(List<int> bytes) {
    try {
      final String jsonString = utf8.decode(bytes);
      return parseFromString(jsonString);
    } catch (e) {
      print('Failed to decode sensor data bytes: $e');
      return null;
    }
  }
}
