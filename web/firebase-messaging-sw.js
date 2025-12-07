// firebase-messaging-sw.js

// This line is for Flutter's service worker, which handles app caching.
// It must be present and must be the first import.
importScripts('flutter_service_worker.js');

// These lines are for Firebase Cloud Messaging.
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-messaging-compat.js');

// Your Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyAX5NloW5VLyqxK_QQwWzXXLI0zu-mfCLU",
  authDomain: "myfellowpet-prod.firebaseapp.com",
  projectId: "myfellowpet-prod",
  storageBucket: "myfellowpet-prod.firebasestorage.app",
  messagingSenderId: "442628504378",
  appId: "1:442628504378:web:78a33db6419de9b42aae03
};

// Initialize Firebase with your config
firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

// This listener is crucial for handling notifications when the app is in the background or closed.
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  const notificationTitle = payload.data.title || 'New Notification';
  const notificationOptions = {
    // *This is the line you need to change.*
    body: payload.data.body,
    icon: '/favicon.png', // <-- You can specify an icon here
    data: payload.data
  };

  // This line displays the notification to the user.
  return self.registration.showNotification(notificationTitle, notificationOptions);
});