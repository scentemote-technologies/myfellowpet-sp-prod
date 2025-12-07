import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoListScreen extends StatefulWidget {
  @override
  _VideoListScreenState createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  late VideoPlayerController _controller;
  bool _isVideoPlaying = false;

  // Method to initialize the video player and play the video
  Future<void> _playVideo(String videoUrl) async {
    // If a video is already playing, pause and dispose the previous controller
    if (_isVideoPlaying) {
      await _controller.pause();
      _controller.dispose();
    }

    // Initialize the new controller
    _controller = VideoPlayerController.network(videoUrl);

    try {
      // Wait for the controller to initialize
      await _controller.initialize();

      // Once initialized, start playing the video
      setState(() {
        _isVideoPlaying = true;
      });
      _controller.play();

      // Show the dialog with the video
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Playing: $videoUrl'),
            content: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                  _controller.pause();
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Handle any errors that might occur during initialization
      print("Error playing video: $e");
    }
  }

  // Method to dispose of the controller when not in use
  @override
  void dispose() {
    if (_isVideoPlaying) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video List'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('videos').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No videos available.'));
          }

          var videos = snapshot.data!.docs;

          return ListView.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              var videoData = videos[index];
              String videoUrl = videoData['url'];
              String videoName = videoData['name'];

              return ListTile(
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                title: Text(videoName),
                onTap: () {
                  _playVideo(videoUrl);
                },
              );
            },
          );
        },
      ),
    );
  }
}
