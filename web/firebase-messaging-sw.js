importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyD_qHAIpnPymA4X_h0BtJYqxAwk1UG_mTg',
  authDomain: 'caribtap.firebaseapp.com',
  projectId: 'caribtap',
  storageBucket: 'caribtap.firebasestorage.app',
  messagingSenderId: '17296052844',
  appId: '1:17296052844:web:e4f14e33763ac26931fe49',
  measurementId: 'G-GCEVP9HB0B',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload?.notification?.title || 'CaribTap';
  const notificationOptions = {
    body: payload?.notification?.body || '',
    icon: '/icons/Icon-192.png',
    data: payload?.data || {},
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
