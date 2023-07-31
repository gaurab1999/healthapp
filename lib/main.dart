import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Step Count',
      home: StepTrackingScreen(),
    );
  }
}

class StepTrackingScreen extends StatefulWidget {
  const StepTrackingScreen({super.key});

  @override
  _StepTrackingScreenState createState() => _StepTrackingScreenState();
}

class _StepTrackingScreenState extends State<StepTrackingScreen> {
  // Lists to store accelerometer and gyroscope data for each axis.
  final List<FlSpot> _accelerometerDataX = [];
  final List<FlSpot> _accelerometerDataY = [];
  final List<FlSpot> _accelerometerDataZ = [];
  final List<FlSpot> _accelerometerMagnitudeData = [];
  final List<FlSpot> _gyroscopeData = [];

  // Step count and tracking status.
  int _stepCount = 0;
  bool _isTracking = false;

  // Stream subscriptions to listen to accelerometer and gyroscope events.
  StreamSubscription<AccelerometerEvent>? _userAccelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  // Minimum time between consecutive steps (milliseconds).
  final int _minTimeBetweenSteps = 600;

  // Threshold for step detection (adjust as needed).
  final double _threshold = 11.0;

  // Gyroscope threshold for detecting swinging (adjust as needed).
  final double _gyroscopeThreshold = 2.0;

  DateTime? _lastStepTime;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
    });

    // Listen to accelerometer events.
    _userAccelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      if (_isTracking) {
        setState(() {
          // Add accelerometer data to respective lists for each axis.
          _accelerometerDataX
              .add(FlSpot(_accelerometerDataX.length.toDouble(), event.x));
          _accelerometerDataY
              .add(FlSpot(_accelerometerDataY.length.toDouble(), event.y));
          _accelerometerDataZ
              .add(FlSpot(_accelerometerDataY.length.toDouble(), event.z));

          // Calculate magnitude and add it to the list.
          double magnitude = _computeMagnitude(event.x, event.y, event.z);
          _accelerometerMagnitudeData.add(
              FlSpot(_accelerometerMagnitudeData.length.toDouble(), magnitude));
        });

        // Detect steps using threshold-based step detection algorithm.
        _detectSteps();
      }
    });

    // Listen to gyroscope events.
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      if (_isTracking) {
        setState(() {
          // Add gyroscope data for the Z-axis to the list.
          _gyroscopeData.add(FlSpot(_gyroscopeData.length.toDouble(), event.z));

          // Apply the moving average filter to the gyroscope data for each axis.
          // You can implement the moving average filter here if needed.
        });
      }
    });
  }

  double _computeMagnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  void _pauseTracking() {
    setState(() {
      _isTracking = !_isTracking;
    });
  }

  void _resetTracking() {
    setState(() {
      // Stop tracking and clear all data lists and step count.
      _isTracking = false;
      _accelerometerDataX.clear();
      _accelerometerDataY.clear();
      _accelerometerDataZ.clear();
      _accelerometerMagnitudeData.clear();
      _gyroscopeData.clear();
      _stepCount = 0;
    });

    // Start tracking again.
    _startTracking();
  }

  void _detectSteps() {
    if (_accelerometerMagnitudeData.length < 3) {
      // Not enough data points for step detection.
      return;
    }

    // Check if the phone is swinging. If yes, return early and don't count the step.
    if (_detectSwinging()) {
      return;
    }

    // Get the last three magnitude values for analysis.
    double magnitude = _accelerometerMagnitudeData.last.y;
    double prevMagnitude =
        _accelerometerMagnitudeData[_accelerometerMagnitudeData.length - 2].y;
    double prevPrevMagnitude =
        _accelerometerMagnitudeData[_accelerometerMagnitudeData.length - 3].y;

    // Check if a possible step is detected based on threshold and increasing magnitude values.
    if (magnitude > _threshold &&
        magnitude > prevMagnitude &&
        magnitude > prevPrevMagnitude) {
      // A possible step detected.
      DateTime now = DateTime.now();
      if (_lastStepTime == null ||
          now.difference(_lastStepTime!) >
              Duration(milliseconds: _minTimeBetweenSteps)) {
        // It's a valid step (not too close to the previous step).
        setState(() {
          _stepCount++;
          _lastStepTime = now;
        });
      }
    }
  }

  @override
  void dispose() {
    _gyroscopeSubscription?.cancel();
    _userAccelerometerSubscription?.cancel();
    super.dispose();
  }

  bool _detectSwinging() {
    if (_gyroscopeData.length < 3) {
      // Not enough data points for swinging detection.
      return false;
    }

    // Get the latest angular velocity value from the gyroscope data for the Z-axis.
    double angularChange = _gyroscopeData.last.y;
    double prevAngularChange = _gyroscopeData[_gyroscopeData.length - 2].y;
    double prevPrevAngularChange = _gyroscopeData[_gyroscopeData.length - 3].y;

    // If there is a significant change in angular velocity,
    // it indicates that the phone is being swung.
    if (angularChange > _gyroscopeThreshold &&
        angularChange > prevAngularChange &&
        angularChange > prevPrevAngularChange) {
      // Add your logic here to handle phone swinging.
      print("Phone swinging detected!");
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step Tracking App'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Charts for displaying accelerometer data for each axis.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("X Axes"),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildChart(_accelerometerDataX, Colors.blue, 'X-Axis'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("Y Axes"),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildChart(_accelerometerDataY, Colors.red, 'Y-Axis'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("Z-Axis"),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildChart(_accelerometerDataZ, Colors.purple, 'Z-axis'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("Magnitude"),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildChart(
                  _accelerometerMagnitudeData, Colors.green, 'Magnitude'),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("Gyroscope Z-Axis"),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildChart(_gyroscopeData, Colors.orange, 'Gyroscope'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Step Count: $_stepCount',
            style: const TextStyle(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _resetTracking();
            },
            child: const Text('Reset'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _pauseTracking();
            },
            child: const Text('Pause'),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<FlSpot> data, Color color, String title) {
    return LineChart(
      LineChartData(
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: data.length.toDouble(),
        minY: -20, // Adjust the range as needed based on your data
        maxY: 20,
        gridData: const FlGridData(show: true),
        lineBarsData: [
          _buildLineChartBarData(data, color),
        ],
      ),
    );
  }

  LineChartBarData _buildLineChartBarData(List<FlSpot> data, Color color) {
    return LineChartBarData(
      spots: data,
      isCurved: false,
      color: [color].first,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}
