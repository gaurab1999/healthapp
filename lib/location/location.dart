import 'dart:async';
import 'dart:math';

import 'package:get_storage/get_storage.dart';
import 'package:sensors_plus/sensors_plus.dart';

// Algorithm URL: https://www.researchgate.net/publication/329526966_A_More_Reliable_Step_Counter_using_Built-in_Accelerometer_in_Smartphone
class StepDetection2 {
  final _box = GetStorage(); // Create a GetStorage instance

  List<AccelerometerEvent> applyLowPassFilter(
      List<AccelerometerEvent> input, double alpha) {
    List<AccelerometerEvent> filteredData = [];

    if (input.isNotEmpty) {
      filteredData.add(input[0]); // Initialize with the first data point

      for (int i = 1; i < input.length; i++) {
        final double x =
            alpha * input[i].x + (1 - alpha) * filteredData[i - 1].x;
        final double y =
            alpha * input[i].y + (1 - alpha) * filteredData[i - 1].y;
        final double z =
            alpha * input[i].z + (1 - alpha) * filteredData[i - 1].z;

        filteredData.add(AccelerometerEvent(x, y, z));
      }
    }
    return filteredData;
  }

  // Function to calculate dynamic threshold (e.g., standard deviation of the sliding window)
  double calculateDynamicThreshold(List<double> data) {
    if (data.isNotEmpty) {
      double mean = data.reduce((a, b) => a + b) / data.length;
      double variance =
          data.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
              data.length;
      double standardDeviation = sqrt(variance);
      return standardDeviation;
    }
    return 0.0;
  }

  detectSteps(List<AccelerometerEvent> data) async {
    final List<double> averageAcceleration = [];

    // Calculate the average acceleration values
    for (final event in data) {
      final a = event.x + event.y + event.z;
      averageAcceleration.add(a);
    }

    List<int> peaks = [];

    // Parameters for dynamic threshold calculation
    double positiveThresholdMultiplier =
        4.7; // Adjust this multiplier as needed for upward peaks
    double negativeThresholdMultiplier =
        -4.7; // Adjust this multiplier as needed for downward peaks
    int slidingWindowWidth =
        15; // Adjust this based on your data collection rate

    // Track a sliding window of recent data points
    List<double> slidingWindow = [];

    for (int i = 0; i < averageAcceleration.length; i++) {
      double currentAcceleration = averageAcceleration[i];
      double positiveDynamicThreshold = positiveThresholdMultiplier *
          calculateDynamicThreshold(slidingWindow);
      double negativeDynamicThreshold = negativeThresholdMultiplier *
          calculateDynamicThreshold(slidingWindow);

      print(
          "THRESHOLD (+) ::: $positiveDynamicThreshold THRESHOLD (-) ::: $negativeDynamicThreshold ACCELERATION :: $currentAcceleration");

      if (currentAcceleration > positiveDynamicThreshold) {
        peaks.add(i);
      } else if (currentAcceleration < negativeDynamicThreshold) {
        peaks.add(i);
      }

      // Move the sliding window by adding the current acceleration
      slidingWindow.add(currentAcceleration);

      // Remove the oldest value if the window size exceeds slidingWindowWidth
      if (slidingWindow.length > slidingWindowWidth) {
        slidingWindow.removeAt(0);
      }
    }

    for (int i = 0; i < peaks.length - 1; i++) {
      final int diff = peaks[i + 1] - peaks[i];
      if (diff > 1) {
        saveIntegerNote(1);
      }
    }
  }

  void startDetection() {
    // Start a periodic timer to collect and process data every 5 seconds
    const duration = Duration(seconds: 5);
    Timer.periodic(duration, (Timer t) {
      collectAndProcessData();
    });
  }

  void collectAndProcessData() {
    List<AccelerometerEvent> accelerometerData = [];

    // Collect data for 5 seconds
    Duration collectionDuration = Duration(seconds: 5);
    DateTime startTime = DateTime.now();

    StreamSubscription<AccelerometerEvent>? subscription;

    // Start data collection
    subscription = accelerometerEvents.listen((AccelerometerEvent event) {
      accelerometerData.add(event);

      // Check if 5 seconds have elapsed
      DateTime currentTime = DateTime.now();
      Duration elapsedDuration = currentTime.difference(startTime);
      if (elapsedDuration >= collectionDuration) {
        // Stop data collection
        subscription?.cancel();

        // Process the collected data
        testStepDetection2(accelerometerData);
        accelerometerData.clear();
      }
    });
  }

  testStepDetection2(List<AccelerometerEvent> rawData) async {
    // Adjust this value as needed
    double alpha = 0.1;

    // Apply low-pass filter
    List<AccelerometerEvent> filteredData = applyLowPassFilter(rawData, alpha);

    // Detect steps
    detectSteps(filteredData);
  }

  // Function to save an integer note
  void saveIntegerNote(int newValue) async {
    await GetStorage.init();
    int previousValue =
        _box.read('integerNote') ?? 0; // Read previous value or default to 0
    int updatedValue = previousValue + newValue;
    _box.write('integerNote', updatedValue); // Save the updated value
  }

  // Function to get the current integer note value
  Future<int> getIntegerNote() async {
    await GetStorage.init();
    return _box.read('integerNote') ?? 0; // Read the value or default to 0
  }
}
