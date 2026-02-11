import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:couldai_user_app/logic/pushup_counter.dart';
import 'package:couldai_user_app/painters/pose_painter.dart';
import 'package:couldai_user_app/utils/camera_utils.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  CameraDescription? _cameraDescription;
  
  final PushupCounter _pushupCounter = PushupCounter();
  List<Pose> _poses = [];
  CustomPainter? _customPainter;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializePoseDetector();
  }

  @override
  void dispose() {
    _stopImageStream();
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  Future<void> _initializePoseDetector() async {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
    );
    _poseDetector = PoseDetector(options: options);
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final cameras = await availableCameras();
    // Try to find front camera
    try {
      _cameraDescription = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
    } catch (e) {
      if (cameras.isNotEmpty) {
        _cameraDescription = cameras.first;
      } else {
        return; // No cameras
      }
    }

    if (_cameraDescription != null) {
      _cameraController = CameraController(
        _cameraDescription!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.nv21 
            : ImageFormatGroup.bgra8888,
      );

      try {
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
          _startImageStream();
        }
      } catch (e) {
        debugPrint("Camera initialization error: $e");
      }
    }
  }

  void _startImageStream() {
    if (_cameraController == null) return;
    
    _cameraController!.startImageStream((CameraImage image) {
      if (_isDetecting) return;
      _isDetecting = true;
      _processImage(image);
    });
  }

  void _stopImageStream() {
    if (_cameraController?.value.isStreamingImages == true) {
      _cameraController?.stopImageStream();
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (_poseDetector == null || _cameraDescription == null) {
      _isDetecting = false;
      return;
    }

    final inputImage = CameraUtils.processCameraImage(image, _cameraDescription!);
    if (inputImage == null) {
      _isDetecting = false;
      return;
    }

    try {
      final poses = await _poseDetector!.processImage(inputImage);
      
      if (poses.isNotEmpty) {
        _pushupCounter.checkPose(poses.first);
      }

      if (mounted) {
        setState(() {
          _poses = poses;
          final size = Size(
            image.width.toDouble(),
            image.height.toDouble(),
          );
          _customPainter = PosePainter(
            poses,
            size,
            InputImageRotation.rotation270deg, // Adjust based on orientation if needed
          );
        });
      }
    } catch (e) {
      debugPrint("Error detecting pose: $e");
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _saveScore() async {
    final prefs = await SharedPreferences.getInstance();
    final currentHigh = prefs.getInt('pushup_highscore') ?? 0;
    if (_pushupCounter.counter > currentHigh) {
      await prefs.setInt('pushup_highscore', _pushupCounter.counter);
    }
  }

  void _finishWorkout() {
    _stopImageStream();
    _saveScore().then((_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Workout Complete!"),
            content: Text(
              "You did ${_pushupCounter.counter} pushups!",
              style: const TextStyle(fontSize: 20),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to home
                },
                child: const Text("OK"),
              )
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Feed
          CameraPreview(_cameraController!),
          
          // Pose Overlay
          if (_customPainter != null)
            CustomPaint(painter: _customPainter),

          // UI Overlay
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: _finishWorkout,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Count: ${_pushupCounter.counter}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Feedback Text
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 30),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _pushupCounter.feedback,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
