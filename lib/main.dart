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
  final List<FlSpot> _accelerometerDataX = [];
  final List<FlSpot> _accelerometerDataY = [];
  final List<FlSpot> _accelerometerMagnitudeData = [];
  final List<FlSpot> _gyroscopeData = [];
  int _stepCount = 0;
  bool _isTracking = false;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  // Threshold for step detection (adjust as needed).
  final double _threshold = 1.8;

  // Gyroscope threshold for detecting swinging (adjust as needed).
  final double _gyroscopeThreshold = 5.0;


  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
    });

    _userAccelerometerSubscription =
        userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      if (_isTracking) {
        setState(() {
          _accelerometerDataX
              .add(FlSpot(_accelerometerDataX.length.toDouble(), event.x));
          _accelerometerDataY
              .add(FlSpot(_accelerometerDataY.length.toDouble(), event.y));

          // Calculate magnitude and add it to the list.
          double magnitude = _computeMagnitude(event.x, event.y, event.z);
          _accelerometerMagnitudeData.add(
              FlSpot(_accelerometerMagnitudeData.length.toDouble(), magnitude));
        });

        // Detect steps using threshold-based step detection algorithm.
        _detectSteps();
      }
    });

    // Enable gyroscope data
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      if (_isTracking) {
        setState(() {
          _gyroscopeData.add(FlSpot(_gyroscopeData.length.toDouble(),
              _computeGyroscopeMagnitude(event.x, event.y, event.z)));
        });
      }
    });
  }

  double _computeMagnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  double _computeGyroscopeMagnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  void _pauseTracking() {
    setState(() {
      _isTracking = !_isTracking;
    });
  }

  void _resetTracking() {
    setState(() {
      _isTracking = false;
      _accelerometerDataX.clear();
      _accelerometerDataY.clear();
      _accelerometerMagnitudeData.clear();
      _gyroscopeData.clear();
      _stepCount = 0;
    });
    _startTracking();
  }

  void _detectSteps() {
    if (_accelerometerMagnitudeData.length < 3) {
      // Not enough data points for step detection.
      return;
    }

    // Get the last three magnitude values for analysis.
    double magnitude = _accelerometerMagnitudeData.last.y;
    double prevMagnitude =
        _accelerometerMagnitudeData[_accelerometerMagnitudeData.length - 2].y;
    double prevPrevMagnitude =
        _accelerometerMagnitudeData[_accelerometerMagnitudeData.length - 3].y;

    if (magnitude > _threshold &&
        magnitude > prevMagnitude &&
        magnitude > prevPrevMagnitude && magnitude < 10) {
      // A possible step detected.           
        // Check gyroscope data before considering the step
        if (_gyroscopeData.isNotEmpty) {
          double gyroscopeMagnitude = _gyroscopeData.last.y;
          if (gyroscopeMagnitude > _gyroscopeThreshold) {
            // Phone is rotating, indicating potential swinging.
            return;
          }
        }

        // It's a valid step (not too close to the previous step).
        setState(() {
          _stepCount++;         
        });
      }    
  }

  @override
  void dispose() {
    _gyroscopeSubscription?.cancel();
    _userAccelerometerSubscription?.cancel();
    super.dispose();
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
            child: Text("Magnitude"),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildChart(
                  _accelerometerMagnitudeData, Colors.green, 'Magnitude'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("Gyroscope"),
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
