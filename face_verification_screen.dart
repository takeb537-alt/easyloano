import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Face Verification Screen
/// Simulates liveness detection by asking user to blink (capture 3 photos).
/// In production, replace with google_ml_kit face detection.
class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  State<FaceVerificationScreen> createState() =>
      _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();
  final List<String> _capturedImages = [];
  int _step = 0; // 0=eyes open, 1=blink, 2=smile
  bool _isCapturing = false;

  final List<Map<String, String>> _steps = [
    {'icon': '👁️', 'instruction': 'Look straight at camera\nKeep eyes open'},
    {'icon': '😑', 'instruction': 'Blink slowly\nClose and open your eyes'},
    {'icon': '😊', 'instruction': 'Smile naturally\nKeep face in frame'},
  ];

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (image != null) {
        _capturedImages.add(image.path);

        if (_step < 2) {
          setState(() {
            _step++;
            _isCapturing = false;
          });
        } else {
          // All 3 captured — return
          if (mounted) {
            Navigator.pop(context, _capturedImages);
          }
        }
      } else {
        setState(() => _isCapturing = false);
      }
    } catch (e) {
      setState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Camera error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _steps[_step];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Face Verification'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 32),

          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: i <= _step ? 32 : 12,
                height: 12,
                decoration: BoxDecoration(
                  color: i < _step
                      ? const Color(0xFF2E7D32)
                      : i == _step
                          ? const Color(0xFF1565C0)
                          : Colors.grey[700],
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }),
          ),
          const SizedBox(height: 48),

          // Face frame
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 220,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1565C0), width: 3),
                  borderRadius: BorderRadius.circular(120),
                ),
              ),
              Text(current['icon']!, style: const TextStyle(fontSize: 80)),
            ],
          ),
          const SizedBox(height: 40),

          // Step indicator
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Step ${_step + 1} of 3',
              style: const TextStyle(
                  color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            current['instruction']!,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const Spacer(),

          // Capture images already taken
          if (_capturedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _capturedImages.map((path) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(File(path)),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: const Align(
                      alignment: Alignment.topRight,
                      child: Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 24),

          // Capture button
          GestureDetector(
            onTap: _isCapturing ? null : _capturePhoto,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isCapturing
                    ? Colors.grey[700]
                    : const Color(0xFF1565C0),
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: _isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt,
                      color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Tap to capture',
              style: TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
