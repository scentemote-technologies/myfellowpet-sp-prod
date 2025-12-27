importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAX5NloW5VLyqxK_QQwWzXXLI0zu-mfCLU",
  authDomain: "myfellowpet-prod.firebaseapp.com",
  projectId: "myfellowpet-prod",
  storageBucket: "myfellowpet-prod.firebasestorage.app",
  messagingSenderId: "442628504378",
  // 🚀 FIX: Added missing closing quote
  appId: "1:442628504378:web:78a33db6419de9b42aae03"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(payload => {
  self.registration.showNotification(
    payload.notification?.title ?? 'New Order',
    {
      body: payload.notification?.body,
      icon: '/icons/Icon-192.png',
      sound: 'default',
      requireInteraction: true,
      data: payload.data
    }
  );
});
