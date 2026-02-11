import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size absoluteImageSize;
  final InputImageRotation rotation;

  PosePainter(this.poses, this.absoluteImageSize, this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.green;

    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellow;

    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blueAccent;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
            Offset(
              translateX(landmark.x, size, absoluteImageSize, rotation),
              translateY(landmark.y, size, absoluteImageSize, rotation),
            ),
            1,
            paint);
      });

      void paintLine(PoseLandmarkType type1, PoseLandmarkType type2, Paint paintType) {
        final PoseLandmark joint1 = pose.landmarks[type1]!;
        final PoseLandmark joint2 = pose.landmarks[type2]!;
        canvas.drawLine(
            Offset(translateX(joint1.x, size, absoluteImageSize, rotation),
                translateY(joint1.y, size, absoluteImageSize, rotation)),
            Offset(translateX(joint2.x, size, absoluteImageSize, rotation),
                translateY(joint2.y, size, absoluteImageSize, rotation)),
            paintType);
      }

      // Draw arms
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
      paintLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, rightPaint);
      paintLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);

      // Draw body
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, paint);
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, paint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, paint);
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.poses != poses;
  }

  double translateX(double x, Size canvasSize, Size imageSize, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return x * canvasSize.width / imageSize.height;
      default:
        return x * canvasSize.width / imageSize.width;
    }
  }

  double translateY(double y, Size canvasSize, Size imageSize, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * canvasSize.height / imageSize.width;
      default:
        return y * canvasSize.height / imageSize.height;
    }
  }
}
