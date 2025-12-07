import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chewie/chewie.dart';

class FullScreenVideoPage extends StatefulWidget {
  final ChewieController chewieController;

  const FullScreenVideoPage({Key? key, required this.chewieController})
      : super(key: key);

  @override
  _FullScreenVideoPageState createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<FullScreenVideoPage> {
  @override
  void initState() {
    super.initState();
    // Lock orientation to landscape on entering fullscreen.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Reset to all allowed orientations on exit.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        // If orientation changes to portrait, exit fullscreen.
        if (orientation == Orientation.portrait) {
          Future.microtask(() {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        }
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Center(
              child: Chewie(controller: widget.chewieController),
            ),
          ),
        );
      },
    );
  }
}
