// lib/webcam_selfie_widget.dart

import 'dart:async';
import 'dart:ui_web';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universal_html/html.dart' as html;

import '../Colors/AppColor.dart';
import '../screens/Boarding/HomeBoarderOnboardPage.dart';


class WebcamSelfieWidget extends StatefulWidget {
  const WebcamSelfieWidget({Key? key}) : super(key: key);

  @override
  State<WebcamSelfieWidget> createState() => _WebcamSelfieWidgetState();
}

class _WebcamSelfieWidgetState extends State<WebcamSelfieWidget> {
  late String _viewId;
  late html.VideoElement _videoElement;
  html.MediaStream? _stream;

  Uint8List? _capturedImageBytes;
  String _error = '';
  bool _isCameraInitializing = true;
  int _cameraInstanceKey = 0; // Used to force recreate the camera view

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() {
    // Unique ID for the platform view
    _viewId = 'webcam-selfie-view-${DateTime.now().microsecondsSinceEpoch}';

    // Create the HTML video element
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..style.objectFit = 'cover'
      ..style.width = '100%'
      ..style.height = '100%';

    // Register the view factory
    platformViewRegistry.registerViewFactory(
      _viewId,
          (int viewId) => _videoElement,
    );

    _startCamera();
  }

  Future<void> _startCamera() async {
    if (!mounted) return;
    setState(() => _isCameraInitializing = true);

    try {
      final mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {'facingMode': 'user'},
        'audio': false,
      });

      _videoElement.srcObject = mediaStream;

      _videoElement.onLoadedMetadata.listen((_) {
        if (mounted) setState(() {
          _isCameraInitializing = false;
        });
      });

      setState(() {
        _stream = mediaStream;
        _error = '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not access camera. Please check permissions and ensure it is not in use by another application.';
          _isCameraInitializing = false;
        });
      }
    }
  }

  Future<void> _stopCamera() async {
    try {
      if (_stream != null) {
        // JS interop call — SAFE, no type casting
        final jsTracks = (_stream as dynamic).getTracks();

        // Convert JSArray to Dart list manually
        for (var i = 0; i < jsTracks.length; i++) {
          try {
            jsTracks[i].stop();
          } catch (err) {
            print("Track stop error: $err");
          }
        }
      }

      // Clear the srcObject
      _videoElement.srcObject = null;
      _stream = null;

      // Remove video element from DOM to ensure hard stop
      if (_videoElement.parentNode != null) {
        _videoElement.remove();
      }

    } catch (e) {
      print("STOP CAMERA FINAL ERROR: $e");
    }
  }




  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_stream == null || _videoElement.videoWidth == 0) {
      // WAIT 100ms AND TRY AGAIN (sometimes video metadata not ready)
      await Future.delayed(const Duration(milliseconds: 120));

      if (_videoElement.videoWidth == 0) {
        print("⚠️ Video not ready, cannot capture.");
        return;
      }
    }

    final canvas = html.CanvasElement(
      width: _videoElement.videoWidth,
      height: _videoElement.videoHeight,
    );

    // DRAW SAFELY
    final ctx = canvas.context2D;
    try {
      ctx.drawImage(_videoElement, 0, 0);
    } catch (e) {
      print("⚠️ drawImage failed: $e");
      return;
    }

    final blob = await canvas.toBlob('image/jpeg', 0.9);
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoadEnd.first;

    if (!mounted) return;

    await _stopCamera(); // <-- IMPORTANT

    setState(() {
      _capturedImageBytes = reader.result as Uint8List?;
    });
  }


  void _retake() {
    setState(() {
      _capturedImageBytes = null;
      _cameraInstanceKey++; // Change key to force HtmlElementView to rebuild
    });
    // Re-initialize and start the camera
    _initializeCamera();
  }

  void _accept() async {
    await _stopCamera();     // <— stop camera before closing popup
    Navigator.of(context).pop(_capturedImageBytes);
  }


  @override
  Widget build(BuildContext context) {
    // Responsive check for button layout
    final isMobile = MediaQuery.of(context).size.width < 500;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        // 🔥 ALWAYS stop camera no matter how the dialog is closed
        await _stopCamera();
      },
      child: Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16.0), // Padding for mobile
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _capturedImageBytes == null ? 'Take a Selfie' : 'Review Your Photo',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _capturedImageBytes == null
                  ? 'Position your face in the center and capture.'
                  : 'Make sure your face is clear and well-lit.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: subtleTextColor,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 375, // Fixed height for camera/image view
              width: 500,  // Fixed width for camera/image view
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildContentView(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildButtonRow(isMobile),
          ],
        ),
      ),
    ),);
  }

  Widget _buildContentView() {
    if (_capturedImageBytes != null) {
      return Image.memory(_capturedImageBytes!, key: const ValueKey('image'), fit: BoxFit.cover);
    }
    if (_isCameraInitializing) {
      return Container(
        key: const ValueKey('loader'),
        color: Colors.grey.shade200,
        child: const Center(
          child: CircularProgressIndicator(
            color: primaryColor,
            strokeWidth: 3,
          ),
        ),
      );
    }
    if (_error.isNotEmpty) {
      return Container(
        key: const ValueKey('error'),
        color: Colors.red.shade50,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_photography_outlined, color: errorColor, size: 48),
                const SizedBox(height: 16),
                Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: errorColor,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return HtmlElementView(
        key: ValueKey(_cameraInstanceKey), viewType: _viewId);
  }

  Widget _buildButtonRow(bool isMobile) {
    if (_capturedImageBytes != null) {
      // Buttons for the review screen (Retake / Accept)
      final List<Widget> buttons = [
        _customButton(
          text: "Retake",
          icon: Icons.refresh,
          onPressed: _retake,
          isPrimary: false,
        ),
        _customButton(
          text: "Accept & Use",
          icon: Icons.check_circle_outline,
          onPressed: _accept,
          isPrimary: true,
          isSuccess: true,
        ),
      ];
      return isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [buttons[0], const SizedBox(height: 12), buttons[1]])
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [buttons[0], const SizedBox(width: 16), buttons[1]]);
    }

    // Buttons for the capture screen (Cancel / Capture)
    final List<Widget> buttons = [
      _customButton(
        text: "Cancel",
        onPressed: () async {
          await _stopCamera();     // <— stop camera first
          Navigator.of(context).pop();
        },
        isPrimary: false,
      ),

      _customButton(
        text: "Capture",
        icon: Icons.camera_alt,
        onPressed: !_isCameraInitializing && _error.isEmpty ? _captureImage : null,
        isPrimary: true,
      ),
    ];
    return isMobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [buttons[1], const SizedBox(height: 12), buttons[0]])
        : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: buttons);
  }

  Widget _customButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isPrimary,
    IconData? icon,
    bool isSuccess = false,
  }) {
    final buttonColor = isSuccess ? successColor : primaryColor;
    final labelColor = isPrimary ? Colors.white : Colors.black87; // <-- fixed name

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: isPrimary ? Colors.white : buttonColor,
        backgroundColor: isPrimary ? buttonColor : Colors.white,
        disabledBackgroundColor: isPrimary ? Colors.grey.shade400 : Colors.white,
        minimumSize: const Size(150, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        elevation: isPrimary ? 4 : 0,
        shadowColor: isPrimary ? buttonColor.withOpacity(0.3) : Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: 20,
              color: isPrimary ? Colors.white : Colors.black, // <-- FIXED
            ),
          if (icon != null) const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: labelColor, // <-- fixed text color variable
            ),
          ),
        ],
      ),
    );
  }

}