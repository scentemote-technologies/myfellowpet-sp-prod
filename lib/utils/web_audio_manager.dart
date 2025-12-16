// lib/utils/web_audio_manager.dart

import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/foundation.dart';

// The ID we will assign to the HTML Audio Element
const String _AUDIO_ELEMENT_ID = 'criticalAudioAlert';

// IMPORTANT: Audio playback often needs user interaction.
// We attach the audio object early to prevent automatic blocking.

void initWebAudio() {
  if (kIsWeb) {
    // 1. Check if the element already exists (e.g., on Flutter hot reload)
    html.AudioElement? audio = html.document.getElementById(_AUDIO_ELEMENT_ID) as html.AudioElement?;

    if (audio == null) {
      // 2. Create the Audio Element
      audio = html.AudioElement();
      audio.id = _AUDIO_ELEMENT_ID;
      audio.src = '/assets/assets/booking_alert.mp3';
      audio.loop = true; // Loop the sound for persistence
      audio.preload = 'auto'; // Load the file immediately

      // 3. Attach it to the document body (hidden)
      audio.style.display = 'none';
      html.document.body?.append(audio);

      if (kDebugMode) {
        print('Web Audio Initialized: Element attached to DOM.');
      }
    }
  }
}

void playCriticalAlertSound() {
  if (kIsWeb) {
    final html.AudioElement? audio = html.document.getElementById(_AUDIO_ELEMENT_ID) as html.AudioElement?;
    if (audio != null) {
      // 4. Try to play immediately. This may fail if no user gesture was detected.
      audio.volume = 1.0; // Ensure max volume
      audio.play().catchError((e) {
        if (kDebugMode) {
          print('Audio playback blocked: $e. Waiting for user interaction.');
        }
      });
    }
  }
}

void stopCriticalAlertSound() {
  if (kIsWeb) {
    final html.AudioElement? audio = html.document.getElementById(_AUDIO_ELEMENT_ID) as html.AudioElement?;
    audio?.pause();
    audio?.currentTime = 0; // Reset playback position
  }
}