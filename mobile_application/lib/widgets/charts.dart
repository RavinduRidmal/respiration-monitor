import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/sensor_data.dart';

/// Real-time sparkline chart for sensor data
class SensorSparkline extends StatelessWidget {
  final List<SensorData> data;
  final String metric; // 'co2', 'humidity', or 'temperature'
  final Color color;
  final String unit;

  const SensorSparkline({
    super.key,
    required this.data,
    required this.metric,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('No data'),
        ),
      );
    }

    final spots = _generateSpots();
    if (spots.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 60,
      padding: const EdgeInsets.all(8),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.1),
              ),
            ),
          ],
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minY: _getMinY(),
          maxY: _getMaxY(),
        ),
      ),
    );
  }

  List<FlSpot> _generateSpots() {
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      final value = _getValue(data[i]);
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
      }
    }
    return spots;
  }

  double? _getValue(SensorData sensorData) {
    switch (metric) {
      case 'co2':
        return sensorData.co2;
      case 'humidity':
        return sensorData.humidity;
      case 'temperature':
        return sensorData.temperature;
      default:
        return null;
    }
  }

  double _getMinY() {
    if (data.isEmpty) return 0;
    
    switch (metric) {
      case 'co2':
        return data.map((d) => d.co2).reduce((a, b) => a < b ? a : b) - 50;
      case 'humidity':
        return 0;
      case 'temperature':
        final min = data.map((d) => d.temperature).reduce((a, b) => a < b ? a : b);
        return min - 5;
      default:
        return 0;
    }
  }

  double _getMaxY() {
    if (data.isEmpty) return 100;
    
    switch (metric) {
      case 'co2':
        return data.map((d) => d.co2).reduce((a, b) => a > b ? a : b) + 50;
      case 'humidity':
        return 100;
      case 'temperature':
        final max = data.map((d) => d.temperature).reduce((a, b) => a > b ? a : b);
        return max + 5;
      default:
        return 100;
    }
  }
}

/// Large time-series chart with selectable metrics
class TimeSeriesChart extends StatefulWidget {
  final List<SensorData> data;
  final String selectedMetric;
  final Function(String) onMetricChanged;

  const TimeSeriesChart({
    super.key,
    required this.data,
    required this.selectedMetric,
    required this.onMetricChanged,
  });

  @override
  State<TimeSeriesChart> createState() => _TimeSeriesChartState();
}

class _TimeSeriesChartState extends State<TimeSeriesChart> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metric selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time Series',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'co2',
                        label: Text('CO₂'),
                      ),
                      ButtonSegment(
                        value: 'humidity',
                        label: Text('Humidity'),
                      ),
                      ButtonSegment(
                        value: 'temperature',
                        label: Text('Temperature'),
                      ),
                    ],
                    selected: {widget.selectedMetric},
                    onSelectionChanged: (selection) {
                      widget.onMetricChanged(selection.first);
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Chart
            SizedBox(
              height: 300,
              child: _buildChart(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(ThemeData theme) {
    if (widget.data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No sensor data available',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final spots = _generateSpots();
    final color = _getMetricColor();
    final unit = _getMetricUnit();
    
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: color,
                  strokeColor: Colors.white,
                  strokeWidth: 1,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: spots.length > 10 ? (spots.length / 5).ceil().toDouble() : null,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < widget.data.length) {
                  final time = widget.data[index].timestamp;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              unit,
              style: theme.textTheme.labelMedium,
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toStringAsFixed(0),
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outline),
            left: BorderSide(color: theme.colorScheme.outline),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getGridInterval(),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => theme.colorScheme.inverseSurface,
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < widget.data.length) {
                  final data = widget.data[index];
                  final time = data.timestamp;
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} $unit\n${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }
                return null;
              }).whereType<LineTooltipItem>().toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
        minY: _getMinY(),
        maxY: _getMaxY(),
      ),
    );
  }

  List<FlSpot> _generateSpots() {
    final spots = <FlSpot>[];
    for (int i = 0; i < widget.data.length; i++) {
      final value = _getValue(widget.data[i]);
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
      }
    }
    return spots;
  }

  double? _getValue(SensorData sensorData) {
    switch (widget.selectedMetric) {
      case 'co2':
        return sensorData.co2;
      case 'humidity':
        return sensorData.humidity;
      case 'temperature':
        return sensorData.temperature;
      default:
        return null;
    }
  }

  Color _getMetricColor() {
    switch (widget.selectedMetric) {
      case 'co2':
        return const Color(0xFF2196F3); // Blue
      case 'humidity':
        return const Color(0xFF00BCD4); // Cyan
      case 'temperature':
        return const Color(0xFFFF5722); // Deep Orange
      default:
        return Colors.grey;
    }
  }

  String _getMetricUnit() {
    switch (widget.selectedMetric) {
      case 'co2':
        return 'CO₂ (ppm)';
      case 'humidity':
        return 'Humidity (%)';
      case 'temperature':
        return 'Temperature (°C)';
      default:
        return '';
    }
  }

  double _getGridInterval() {
    if (widget.data.isEmpty) return 10;
    
    switch (widget.selectedMetric) {
      case 'co2':
        final max = _getMaxY();
        return max > 2000 ? 500 : 100;
      case 'humidity':
        return 20;
      case 'temperature':
        return 5;
      default:
        return 10;
    }
  }

  double _getMinY() {
    if (widget.data.isEmpty) return 0;
    
    switch (widget.selectedMetric) {
      case 'co2':
        final min = widget.data.map((d) => d.co2).reduce((a, b) => a < b ? a : b);
        return (min - 100).clamp(0, double.infinity);
      case 'humidity':
        return 0;
      case 'temperature':
        final min = widget.data.map((d) => d.temperature).reduce((a, b) => a < b ? a : b);
        return min - 10;
      default:
        return 0;
    }
  }

  double _getMaxY() {
    if (widget.data.isEmpty) return 100;
    
    switch (widget.selectedMetric) {
      case 'co2':
        final max = widget.data.map((d) => d.co2).reduce((a, b) => a > b ? a : b);
        return max + 100;
      case 'humidity':
        return 100;
      case 'temperature':
        final max = widget.data.map((d) => d.temperature).reduce((a, b) => a > b ? a : b);
        return max + 10;
      default:
        return 100;
    }
  }
}

/// Metric card displaying current value with sparkline
class MetricCard extends StatelessWidget {
  final String title;
  final double value;
  final String unit;
  final List<SensorData> data;
  final String metric;
  final Color color;
  final IconData icon;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.data,
    required this.metric,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 180, // Fixed height to prevent overflow
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SensorSparkline(
                  data: data,
                  metric: metric,
                  color: color,
                  unit: unit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
