import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StepTrackingScreen(),
    );
  }
}

class StepTrackingScreen extends StatefulWidget {
  @override
  _StepTrackingScreenState createState() => _StepTrackingScreenState();
}

class _StepTrackingScreenState extends State<StepTrackingScreen> {
  List<ChartData> _accelerometerDataX = [];
  List<ChartData> _accelerometerDataY = [];
  List<ChartData> _accelerometerDataZ = [];

  List<ChartData> _userAccelerometerDataX = [];
  List<ChartData> _userAccelerometerDataY = [];
  List<ChartData> _userAccelerometerDataZ = [];

  int _stepCount = 0;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  final List<double> _accelerometerMagnitudeData = [];
  final List<double> _gyroscopeData = [];
  static const int minSizeOfSensorData = 4;

  // Step count and tracking status.
  bool _isTracking = false;

  // Time and threshold constants.
  final int _minTimeBetweenSteps = 700;
  final double _threshold = 10.5;
  final double _gyroscopeThreshold = 4.0;
  DateTime? _lastStepTime;

// New algorithm variables.
// Holds the raw accelerometer data collected over a certain period.
  List<AccelerometerEvent> rawAccData = [];

// Stores the indices or timestamps where peaks were detected in the smoothed accelerometer data.
  List<double> detectedPeaks = [];

// Specifies the duration for which accelerometer data should be collected before applying the algorithm.
  final Duration dataCollectionDuration = Duration(seconds: 15);

// Tracks the timestamp when data collection started.
  DateTime? startTime;

// Holds net magnitude values calculated from the raw accelerometer data.
  List<double> magData = [];

// Stores the net magnitude values after applying a moving average filter.
  List<double> smoothedNetMagValues = [];

// Counts the number of steps detected using the new algorithm.
  int stepCountNew = 0;
  bool isTracking = false;
  @override
  void initState() {
    super.initState();
    isTracking = true;
    _startListeningToUserAccelerometer();
  }

  //calculate average magnitude using all three axes
  double _computeMagnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  bool _isDataCollectionComplete() {
    // Calculate the duration since data collection started.
    Duration elapsedTime = DateTime.now().difference(startTime!);

    // Compare the elapsed time with the predefined data collection duration.
    // If the elapsed time is greater than or equal to the duration, return true.
    return elapsedTime >= dataCollectionDuration;
  }

  void _startListeningToUserAccelerometer() {
    startTime = DateTime.now();
    // _userAccelerometerSubscription =
    //     userAccelerometerEvents.listen((UserAccelerometerEvent event) {
    //   if (!isTracking) {
    //     return;
    //   }
    //   double magnitude = _computeMagnitude(event.x, event.y, event.z);
    //   _accelerometerMagnitudeData.add(magnitude);
    //   setState(() {
    //     _userAccelerometerDataX.add(
    //         ChartData(_userAccelerometerDataX.length.toDouble(), magnitude));
    //   });

    // });
    _accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      if (!isTracking) {
        return;
      }
      double magnitude = _computeMagnitude(event.x, event.y, event.z);
      rawAccData.add(event);
      setState(() {
        _userAccelerometerDataX.add(
            ChartData(_userAccelerometerDataX.length.toDouble(), magnitude));
      });
      if (_isDataCollectionComplete()) {
        _applyNewAlgorithm();
        _detectSteps();
      }
    });
  }

  // Detect swinging motion using gyroscope data.
  bool _detectSwinging() {
    if (_gyroscopeData.length < minSizeOfSensorData) return false;

    // Compare the current angular change with previous values.
    double angularChange = _gyroscopeData.last;
    double prevAngularChange = _gyroscopeData[_gyroscopeData.length - 2];
    double prevPrevAngularChange = _gyroscopeData[_gyroscopeData.length - 3];
    double prevPrevPrevAngularChange =
        _gyroscopeData[_gyroscopeData.length - 4];

    // If significant angular change is detected, swinging is detected.
    if (angularChange > _gyroscopeThreshold &&
        angularChange > prevAngularChange &&
        angularChange > prevPrevAngularChange &&
        angularChange > prevPrevPrevAngularChange) {
      return true;
    }
    return false;
  }

  void _detectSteps() {
    if (_accelerometerMagnitudeData.length < minSizeOfSensorData) {
      return; // Not enough data points for accurate step detection.
    }

    if (_detectSwinging()) {
      return; // If swinging is detected, return early.
    }

    double magnitude = _accelerometerMagnitudeData.last;
    double prevMagnitude =
        _accelerometerMagnitudeData[_accelerometerMagnitudeData.length - 2];
    double prevPrevMagnitude =
        _accelerometerMagnitudeData[_accelerometerMagnitudeData.length - 3];
    double prevPrevPrevMagnitude =
        _accelerometerMagnitudeData[_accelerometerMagnitudeData.length - 4];
    if (magnitude > _threshold) {
      print(
          "Last 4 magnitudes are : $magnitude :: $prevMagnitude :: $prevPrevMagnitude :: $prevPrevPrevMagnitude");
    }
    // Check for both peak and valley based on magnitude comparisons.
    if (_isPeak(
        magnitude, prevMagnitude, prevPrevMagnitude, prevPrevPrevMagnitude)) {
      // Find the corresponding valley index.
      print("peak detected");
      int valleyIndex =
          _findValleyIndex(_accelerometerMagnitudeData.length - 1);

      if (valleyIndex != -1) {
        print("valley detected");
        // A complete step is detected.
        _handleStepDetected(valleyIndex);
      }
    }
  }

  bool _isPeak(
      double current, double prev, double prevPrev, double prevPrevPrev) {
    // Check if the current magnitude is a peak based on comparisons.
    return (current > _threshold &&
        current > prev &&
        current > prevPrev &&
        current > prevPrevPrev);
  }

  int _findValleyIndex(int currentIndex) {
    // Start searching for a valley from the current index.
    for (int i = currentIndex;
        i < _accelerometerMagnitudeData.length - 1;
        i++) {
      if (_isValley(i)) {
        return i; // Return the index of the detected valley.
      }
    }
    return -1; // No valley detected.
  }

  bool _isValley(int index) {
    // Compare the data point at index with its neighbors to detect a valley.
    double currentMagnitude = _accelerometerMagnitudeData[index];
    double nextMagnitude = _accelerometerMagnitudeData[index + 1];

    return currentMagnitude < nextMagnitude;
  }

  void _handleStepDetected(int valleyIndex) {
    DateTime now = DateTime.now();

    if (_lastStepTime == null ||
        now.difference(_lastStepTime!) >
            Duration(milliseconds: _minTimeBetweenSteps)) {
      // Increment the step count.
      _stepCount++;
      _lastStepTime = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Step Tracking App'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Combined User Accelerometer Data"),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildCombinedChart(
                  _accelerometerDataX, Colors.blue, 'Accelerometer Data'),
            ),
          ),
          Text("Combined Accelerometer Data"),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildCombinedChart(_userAccelerometerDataX, Colors.orange,
                  'User Accelerometer Data'),
            ),
          ),
          TextButton(
            onPressed: () {
              _resetTracking();
            },
            child: Text('Reset'),
          ),
          TextButton(
            onPressed: () {
              _pauseTracking();
            },
            child: Text('Pause'),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  // Widget _buildChart(List<FlSpot> data, Color color, String title) {
  //   return LineChart(
  //     LineChartData(
  //       titlesData: FlTitlesData(show: false),
  //       borderData: FlBorderData(show: false),
  //       minX: 0,
  //       maxX: data.length.toDouble(),
  //       minY: -13, // Adjust the range as needed based on your data
  //       maxY: 13,
  //       gridData: FlGridData(show: true),
  //       lineBarsData: [
  //         _buildLineChartBarData(data, color),
  //       ],
  //     ),
  //   );
  // }

  LineChartBarData _buildLineChartBarData(List<FlSpot> data, Color color) {
    return LineChartBarData(
      spots: data,
      isCurved: false,
      color: [color].first,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  @override
  void dispose() {
    _userAccelerometerSubscription?.cancel();
    super.dispose();
  }

  void _pauseTracking() {
    setState(() {
      isTracking = !isTracking;
    });
  }

  void _resetTracking() {
    setState(() {
      _accelerometerDataX.clear();
      _accelerometerDataY.clear();
      _accelerometerDataZ.clear();
      _userAccelerometerDataX.clear();
      _userAccelerometerDataY.clear();
      _userAccelerometerDataZ.clear();
    });
  }

  Widget _buildCombinedChart(List<ChartData> xData, Color color, String title) {
    return SfCartesianChart(
      primaryXAxis: NumericAxis(),
      primaryYAxis: NumericAxis(),
      zoomPanBehavior: ZoomPanBehavior(
          enablePanning: true, // Enable panning
          enableSelectionZooming: true, // Enable zooming
          enablePinching: true,
          zoomMode: ZoomMode.xy),
      series: <LineSeries<ChartData, double>>[
        LineSeries<ChartData, double>(
          dataSource: xData,
          color: Colors.amber,
          xValueMapper: (ChartData chartData, _) => chartData.x,
          yValueMapper: (ChartData chartData, _) => chartData.y,
          name: 'X-Axis',
        ),
      ],
    );
  }

  Widget _buildChart(List<ChartData> data, Color color, String title) {
    return SfCartesianChart(
      primaryXAxis: NumericAxis(),
      primaryYAxis: NumericAxis(),
      zoomPanBehavior: ZoomPanBehavior(
          enablePanning: true, // Enable panning
          enableSelectionZooming: true, // Enable zooming
          enablePinching: true),
      series: <LineSeries<ChartData, double>>[
        LineSeries<ChartData, double>(
          dataSource: data,
          xValueMapper: (ChartData chartData, _) => chartData.x,
          yValueMapper: (ChartData chartData, _) => chartData.y,
          color: color,
        ),
      ],
    );
  }

  // Apply the new algorithm to process accelerometer data.
  void _applyNewAlgorithm() {
    // Calculate net magnitude values and smooth them using a moving average.
    magData = calculateNetMagnitudeValues(rawAccData);
    smoothedNetMagValues = applyMovingAverageFilter(magData, windowSize: 15);

    for (var element in smoothedNetMagValues) {
      _accelerometerDataX
          .add(ChartData(_accelerometerDataX.length.toDouble(), element));
    }

    setState(() {});

    // Detect peaks in the smoothed data.
    detectedPeaks = detectPeaks(smoothedNetMagValues, threshold: 0.6);

    // Calculate step lengths using detected peaks.
    calculateStepLengths(detectedPeaks);

    // Reset the start time and raw accelerometer data for the next cycle.
    startTime = DateTime.now();
    rawAccData = [];
  }

// Calculate net magnitude values from accelerometer data.
  List<double> calculateNetMagnitudeValues(List<AccelerometerEvent> data) {
    // Calculate the average magnitude.
    double avgMag = data
            .map((event) => _computeMagnitude(event.x, event.y, event.z))
            .reduce((a, b) => a + b) /
        data.length;

    // Subtract average magnitude from each value to get net magnitude.
    return data
        .map((event) => _computeMagnitude(event.x, event.y, event.z) - avgMag)
        .toList();
  }

// Apply a moving average filter to smooth data.
  List<double> applyMovingAverageFilter(List<double> rawData,
      {required int windowSize}) {
    List<double> smoothedData = [];

    for (int i = 0; i < rawData.length; i++) {
      double sum = 0.0;
      int count = 0;

      // Calculate the sum of data points within the window.
      for (int j = i - windowSize ~/ 2; j <= i + windowSize ~/ 2; j++) {
        if (j >= 0 && j < rawData.length) {
          sum += rawData[j];
          count++;
        }
      }

      // Calculate the average and add to smoothedData.
      smoothedData.add(sum / count);
    }

    return smoothedData;
  }

// Detect peaks in smoothed data using a specified threshold.
  List<double> detectPeaks(List<double> smoothedData,
      {required double threshold}) {
    List<double> peaks = [];

    // Iterate through the smoothed data points.
    for (int i = 1; i < smoothedData.length - 1; i++) {
      // Check if the current data point is a peak by comparing it with its neighbors.
      if (

          /// It checks if the data point's value is significantly higher than the baseline threshold level,
          /// helping filter out small fluctuations that might not indicate a meaningful peak.
          smoothedData[i] > threshold &&

              /// If the current data point is higher than the previous data point,
              /// it indicates an upward trend in the data,
              /// suggesting that the current point could be part of a peak.
              smoothedData[i] > smoothedData[i - 1] &&

              /// If the current data point is higher than the next data point,
              /// it indicates a descending trend in the data after the peak,
              /// which reinforces the identification of a peak.
              smoothedData[i] > smoothedData[i + 1]) {
        // If all conditions are met, this data point is considered a peak.
        peaks.add(i.toDouble()); // Store the index of the detected peak.
      }
    }

    return peaks;
  }

// Calculate step lengths based on detected peaks.
  void calculateStepLengths(List<double> peaks) {
    stepCountNew = 0;

    for (int i = 1; i < peaks.length; i++) {
      stepCountNew++;
    }

    // Save the new step count to local storage.
    if (stepCountNew == 0) return;
    setState(() {
      _stepCount = stepCountNew;
    });
  }
}

class ChartData {
  final double x;
  final double y;

  ChartData(this.x, this.y);
}
