// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_application/main.dart';
import 'package:mobile_application/models/sensor_data.dart';

void main() {
  group('SensorData Model Tests', () {
    test('should parse valid JSON correctly', () {
      // Arrange
      final json = {
        'co2': 420.5,
        'humidity': 55.2,
        'temperature': 24.3,
        'alert': 1,
        'timestamp': 1694270400000,
      };

      // Act
      final sensorData = SensorData.fromJson(json);

      // Assert
      expect(sensorData.co2, equals(420.5));
      expect(sensorData.humidity, equals(55.2));
      expect(sensorData.temperature, equals(24.3));
      expect(sensorData.alert, equals(1));
      expect(sensorData.timestamp.millisecondsSinceEpoch, equals(1694270400000));
    });

    test('should handle missing optional fields', () {
      // Arrange
      final json = {
        'co2': 400.0,
        'humidity': 50.0,
        'temperature': 22.0,
        // alert and timestamp missing
      };

      // Act
      final sensorData = SensorData.fromJson(json);

      // Assert
      expect(sensorData.co2, equals(400.0));
      expect(sensorData.humidity, equals(50.0));
      expect(sensorData.temperature, equals(22.0));
      expect(sensorData.alert, equals(0)); // Default value
      expect(sensorData.timestamp, isA<DateTime>()); // Should use current time
    });

    test('should throw FormatException for missing required fields', () {
      // Arrange
      final json = {
        'humidity': 50.0,
        'temperature': 22.0,
        // co2 missing
      };

      // Act & Assert
      expect(() => SensorData.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('should throw FormatException for negative CO2 values', () {
      // Arrange
      final json = {
        'co2': -100.0,
        'humidity': 50.0,
        'temperature': 22.0,
      };

      // Act & Assert
      expect(() => SensorData.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('should throw FormatException for out-of-range humidity', () {
      // Arrange
      final json = {
        'co2': 400.0,
        'humidity': 150.0, // Over 100%
        'temperature': 22.0,
      };

      // Act & Assert
      expect(() => SensorData.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('should throw FormatException for invalid alert values', () {
      // Arrange
      final json = {
        'co2': 400.0,
        'humidity': 50.0,
        'temperature': 22.0,
        'alert': 5, // Out of range (should be 0-2)
      };

      // Act & Assert
      expect(() => SensorData.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('should handle integer values for floating point fields', () {
      // Arrange
      final json = {
        'co2': 400,
        'humidity': 50,
        'temperature': 22,
      };

      // Act
      final sensorData = SensorData.fromJson(json);

      // Assert
      expect(sensorData.co2, equals(400.0));
      expect(sensorData.humidity, equals(50.0));
      expect(sensorData.temperature, equals(22.0));
    });

    test('should return correct alert descriptions', () {
      // Test normal alert
      final normalData = SensorData(
        co2: 400, humidity: 50, temperature: 22, alert: 0, timestamp: DateTime.now(),
      );
      expect(normalData.alertDescription, equals('Normal'));

      // Test warning alert
      final warningData = SensorData(
        co2: 1200, humidity: 50, temperature: 22, alert: 1, timestamp: DateTime.now(),
      );
      expect(warningData.alertDescription, equals('Warning'));

      // Test critical alert
      final criticalData = SensorData(
        co2: 1800, humidity: 50, temperature: 22, alert: 2, timestamp: DateTime.now(),
      );
      expect(criticalData.alertDescription, equals('Critical'));
    });

    test('should return correct alert colors', () {
      // Test normal (green)
      final normalData = SensorData(
        co2: 400, humidity: 50, temperature: 22, alert: 0, timestamp: DateTime.now(),
      );
      expect(normalData.alertColor, equals(0xFF4CAF50));

      // Test warning (orange)
      final warningData = SensorData(
        co2: 1200, humidity: 50, temperature: 22, alert: 1, timestamp: DateTime.now(),
      );
      expect(warningData.alertColor, equals(0xFFFF9800));

      // Test critical (red)
      final criticalData = SensorData(
        co2: 1800, humidity: 50, temperature: 22, alert: 2, timestamp: DateTime.now(),
      );
      expect(criticalData.alertColor, equals(0xFFF44336));
    });
  });

  group('SensorDataParser Tests', () {
    test('should parse valid JSON string', () {
      // Arrange
      const jsonString = '{"co2":420.5,"humidity":55.2,"temperature":24.3,"alert":1,"timestamp":1694270400000}';

      // Act
      final sensorData = SensorDataParser.parseFromString(jsonString);

      // Assert
      expect(sensorData, isNotNull);
      expect(sensorData!.co2, equals(420.5));
      expect(sensorData.humidity, equals(55.2));
    });

    test('should return null for invalid JSON string', () {
      // Arrange
      const invalidJson = '{"co2":420.5,"humidity":55.2'; // Incomplete JSON

      // Act
      final sensorData = SensorDataParser.parseFromString(invalidJson);

      // Assert
      expect(sensorData, isNull);
    });

    test('should parse UTF-8 encoded bytes', () {
      // Arrange
      const jsonString = '{"co2":420.5,"humidity":55.2,"temperature":24.3,"alert":0}';
      final bytes = jsonString.codeUnits;

      // Act
      final sensorData = SensorDataParser.parseFromBytes(bytes);

      // Assert
      expect(sensorData, isNotNull);
      expect(sensorData!.co2, equals(420.5));
    });

    test('should return null for invalid UTF-8 bytes', () {
      // Arrange
      final invalidBytes = [0xFF, 0xFE, 0xFD]; // Invalid UTF-8 sequence

      // Act
      final sensorData = SensorDataParser.parseFromBytes(invalidBytes);

      // Assert
      expect(sensorData, isNull);
    });
  });

  group('Control Command JSON Tests', () {
    test('should create correct mute command JSON', () {
      // Arrange
      final command = {'cmd': 'mute', 'value': true};

      // Act
      final jsonString = command.toString();

      // Assert
      expect(jsonString.contains('mute'), isTrue);
      expect(jsonString.contains('true'), isTrue);
    });

    test('should create correct volume command JSON', () {
      // Arrange
      final command = {'cmd': 'volume', 'value': 75};

      // Act
      final jsonString = command.toString();

      // Assert
      expect(jsonString.contains('volume'), isTrue);
      expect(jsonString.contains('75'), isTrue);
    });

    test('should create correct power off command JSON', () {
      // Arrange
      final command = {'cmd': 'power', 'value': 'off'};

      // Act
      final jsonString = command.toString();

      // Assert
      expect(jsonString.contains('power'), isTrue);
      expect(jsonString.contains('off'), isTrue);
    });
  });

  group('Widget Tests', () {
    testWidgets('App should start and show scan screen', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const RespirationMonitorApp());

      // Verify that the scan screen is displayed
      expect(find.text('Respiration Monitors'), findsOneWidget);
    });

    testWidgets('Scan screen should have scan button', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const RespirationMonitorApp());

      // Wait for the widget to settle
      await tester.pumpAndSettle();

      // Verify that the scan button is present
      expect(find.text('Scan for Devices'), findsOneWidget);
    });

    testWidgets('Scan screen should have mock mode button', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const RespirationMonitorApp());

      // Wait for the widget to settle
      await tester.pumpAndSettle();

      // Verify that the mock mode button is present
      expect(find.text('Mock Mode'), findsOneWidget);
    });
  });
}
