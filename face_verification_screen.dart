// ============================================
// EasyLoan - FaceVerificationScreen
// Google ML Kit face detection + blink check
// Captures 3 photos, uploads to Firebase Storage
// ============================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../widgets/common_widgets.dart';

class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  State<FaceVerificationScreen> createState() =>
      _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true, // For blink detection
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  final FirestoreService _firestoreService = FirestoreService();

  // Verification state
  String _statusText = 'Position your face in the circle';
  String _instructionText = 'Please blink once to verify';
  _VerificationStep _currentStep = _VerificationStep.positioning;

  bool _isDetecting = false;
  bool _blinkDetected = false;
  bool _isProcessing = false;
  int _photosCaptered = 0;

  final List<File> _capturedPhotos = [];
  List<CameraDescription> _cameras = [];

  // Blink detection counters
  double _leftEyeOpen = 1.0;
  double _rightEyeOpen = 1.0;
  bool _eyesClosed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _statusText = 'No camera available');
        return;
      }

      // Use front camera for face verification
      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium, // Low-end device friendly
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() {});

      // Start image stream for real-time face detection
      await _cameraController!.startImageStream(_processFrame);
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Camera error: Please restart app');
      }
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isDetecting || !mounted) return;
    if (_currentStep == _VerificationStep.completed) return;

    _isDetecting = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) {
        _isDetecting = false;
        return;
      }

      if (faces.isEmpty) {
        setState(() {
          _statusText = 'No face detected';
          _currentStep = _VerificationStep.positioning;
        });
        _isDetecting = false;
        return;
      }

      final face = faces.first;

      // Check face is centered enough
      final imageWidth =
          _cameraController!.value.previewSize?.height ?? 480;
      final imageHeight =
          _cameraController!.value.previewSize?.width ?? 640;
      final faceCenter = face.boundingBox.center;
      final imageCenter = Offset(imageWidth / 2, imageHeight / 2);
      final distanceFromCenter = (faceCenter - imageCenter).distance;

      if (distanceFromCenter > 100) {
        setState(() {
          _statusText = 'Center your face';
          _currentStep = _VerificationStep.positioning;
        });
        _isDetecting = false;
        return;
      }

      // Blink detection using eye open probability
      _leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
      _rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;

      if (_currentStep == _VerificationStep.blinking) {
        final eyesClosed = _leftEyeOpen < 0.2 && _rightEyeOpen < 0.2;
        final eyesOpen = _leftEyeOpen > 0.8 && _rightEyeOpen > 0.8;

        if (eyesClosed && !_eyesClosed) {
          _eyesClosed = true;
          setState(() => _statusText = '👍 Blink detected! Hold still...');
        } else if (eyesOpen && _eyesClosed) {
          // Full blink completed
          _eyesClosed = false;
          _blinkDetected = true;
          setState(() {
            _currentStep = _VerificationStep.capturing;
            _statusText = 'Great! Capturing photos...';
          });
          await _capturePhotos();
        }
      } else if (_currentStep == _VerificationStep.positioning) {
        setState(() {
          _currentStep = _VerificationStep.blinking;
          _statusText = 'Face detected! Now blink once';
        });
      }
    } catch (e) {
      debugPrint('Face detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _capturePhotos() async {
    await _cameraController?.stopImageStream();
    setState(() => _isProcessing = true);

    try {
      for (int i = 0; i < 3; i++) {
        setState(() {
          _photosCaptered = i + 1;
          _statusText = 'Capturing photo ${i + 1} of 3...';
        });

        await Future.delayed(const Duration(milliseconds: 500));

        if (_cameraController != null &&
            _cameraController!.value.isInitialized) {
          final photo = await _cameraController!.takePicture();
          _capturedPhotos.add(File(photo.path));
        }
      }

      // Upload to Firebase Storage
      setState(() => _statusText = 'Uploading photos...');
      await _uploadAndSave();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Capture failed. Please try again.';
        _currentStep = _VerificationStep.positioning;
      });
      // Restart stream
      await _cameraController?.startImageStream(_processFrame);
    }
  }

  Future<void> _uploadAndSave() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final List<String> photoUrls = [];

    for (int i = 0; i < _capturedPhotos.length; i++) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('face_verification')
          .child(userId)
          .child('photo_$i.jpg');

      await ref.putFile(_capturedPhotos[i]);
      final url = await ref.getDownloadURL();
      photoUrls.add(url);
    }

    // Generate simple face hash from file size (basic uniqueness)
    final faceHash = photoUrls.fold(
      '',
      (prev, url) => prev + url.hashCode.toString(),
    );

    await _firestoreService.saveFaceData(
      photoUrls: photoUrls,
      faceHash: faceHash,
    );

    if (mounted) {
      setState(() {
        _currentStep = _VerificationStep.completed;
        _statusText = 'Face verified! ✓';
        _isProcessing = false;
      });

      await Future.delayed(const Duration(milliseconds: 1500));
      Navigator.pushReplacementNamed(context, AppRoutes.basicDetails);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Face Verification',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Camera preview
                if (_cameraController != null &&
                    _cameraController!.value.isInitialized)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: CameraPreview(_cameraController!),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),

                // Oval face overlay
                _FaceOverlay(
                  step: _currentStep,
                  isProcessing: _isProcessing,
                  photosCaptered: _photosCaptered,
                ),
              ],
            ),
          ),

          // Status panel
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Step dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _VerificationStep.values
                      .map((step) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: step == _currentStep ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: step == _VerificationStep.completed
                                  ? AppColors.success
                                  : step == _currentStep
                                      ? Colors.white
                                      : Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 16),

                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _currentStep == _VerificationStep.positioning
                      ? 'Align your face within the oval'
                      : _currentStep == _VerificationStep.blinking
                          ? 'Look straight and blink once'
                          : _currentStep == _VerificationStep.capturing
                              ? 'Stay still while we capture photos'
                              : 'Verification complete!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                ),

                const SizedBox(height: 24),

                // Tips
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.yellow, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Remove glasses • Good lighting • Look straight',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
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

// ─── Face Overlay Widget ─────────────────────

class _FaceOverlay extends StatelessWidget {
  final _VerificationStep step;
  final bool isProcessing;
  final int photosCaptered;

  const _FaceOverlay({
    required this.step,
    required this.isProcessing,
    required this.photosCaptered,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ovalWidth = size.width * 0.65;
    final ovalHeight = ovalWidth * 1.25;

    Color borderColor;
    switch (step) {
      case _VerificationStep.positioning:
        borderColor = Colors.white60;
        break;
      case _VerificationStep.blinking:
        borderColor = AppColors.primary;
        break;
      case _VerificationStep.capturing:
        borderColor = AppColors.warning;
        break;
      case _VerificationStep.completed:
        borderColor = AppColors.success;
        break;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Dark overlay with oval cutout
        CustomPaint(
          size: Size(size.width, size.height * 0.75),
          painter: _OvalOverlayPainter(
            ovalWidth: ovalWidth,
            ovalHeight: ovalHeight,
          ),
        ),

        // Animated border oval
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: ovalWidth,
          height: ovalHeight,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 3),
            borderRadius: BorderRadius.circular(ovalWidth / 2),
          ),
        ),

        // Processing indicator
        if (isProcessing)
          Positioned(
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Photo $photosCaptered of 3',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Completed checkmark
        if (step == _VerificationStep.completed)
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 32),
          ),
      ],
    );
  }
}

class _OvalOverlayPainter extends CustomPainter {
  final double ovalWidth;
  final double ovalHeight;

  const _OvalOverlayPainter({
    required this.ovalWidth,
    required this.ovalHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    path.addOval(Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: ovalWidth,
      height: ovalHeight,
    ));

    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OvalOverlayPainter oldDelegate) => false;
}

enum _VerificationStep { positioning, blinking, capturing, completed }