import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum PushupState { neutral, up, down }

class PushupCounter {
  int counter = 0;
  PushupState state = PushupState.neutral;
  
  // Thresholds
  final double startAngle = 160.0; // Arms extended
  final double downAngle = 90.0;   // Arms bent
  
  // Feedback message
  String feedback = "Get into position";

  void reset() {
    counter = 0;
    state = PushupState.neutral;
    feedback = "Get into position";
  }

  void checkPose(Pose pose) {
    // We need landmarks for shoulders, elbows, and wrists.
    // Left arm
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];

    // Right arm
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    // Check visibility
    bool leftVisible = (leftShoulder?.likelihood ?? 0) > 0.5 &&
                       (leftElbow?.likelihood ?? 0) > 0.5 &&
                       (leftWrist?.likelihood ?? 0) > 0.5;

    bool rightVisible = (rightShoulder?.likelihood ?? 0) > 0.5 &&
                        (rightElbow?.likelihood ?? 0) > 0.5 &&
                        (rightWrist?.likelihood ?? 0) > 0.5;

    if (!leftVisible && !rightVisible) {
      feedback = "Can't see arms";
      return;
    }

    double leftAngle = 180.0;
    double rightAngle = 180.0;

    if (leftVisible) {
      leftAngle = _getAngle(leftShoulder!, leftElbow!, leftWrist!);
    }
    
    if (rightVisible) {
      rightAngle = _getAngle(rightShoulder!, rightElbow!, rightWrist!);
    }

    // Use the visible arm, or average if both are visible
    double angle;
    if (leftVisible && rightVisible) {
      angle = (leftAngle + rightAngle) / 2;
    } else if (leftVisible) {
      angle = leftAngle;
    } else {
      angle = rightAngle;
    }

    // State Machine
    if (angle > startAngle) {
      if (state == PushupState.down) {
        counter++;
        feedback = "Good job! ($counter)";
      } else {
        feedback = "Go down";
      }
      state = PushupState.up;
    } else if (angle < downAngle) {
      state = PushupState.down;
      feedback = "Push up!";
    } else {
      if (state == PushupState.up) {
        feedback = "Lower...";
      } else if (state == PushupState.down) {
        feedback = "Higher...";
      }
    }
  }

  static double _getAngle(PoseLandmark first, PoseLandmark mid, PoseLandmark last) {
    double result =
        math.atan2(last.y - mid.y, last.x - mid.x) -
        math.atan2(first.y - mid.y, first.x - mid.x);
    result = result * 180 / math.pi;
    result = result.abs(); // Angle should never be negative
    if (result > 180) {
      result = 360.0 - result; // Always get the acute representation
    }
    return result;
  }
}
