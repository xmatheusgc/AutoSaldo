// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyD8sOTctNGOIfjebTm484eRmyKhaA9Gvls",
  authDomain: "autosaldo.firebaseapp.com",
  projectId: "autosaldo",
  storageBucket: "autosaldo.firebasestorage.app",
  messagingSenderId: "1062280297793",
  appId: "1:1062280297793:web:3555c8403f4f370b6175c0",
  measurementId: "G-X1PV2P4EP9"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);