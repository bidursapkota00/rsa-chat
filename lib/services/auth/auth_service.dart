import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatapp_flutter/services/encrypt/rsa.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  //instance of auth & firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  final RSA rsa = RSA();

  //get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<UserCredential> signUpWithEmailPassword(
      String email, String password) async {
    try {
      // Create user
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      RSAKeyPair keyPair = rsa.generateKeyPair();
      BigInt publicKey = keyPair.publicKey;
      BigInt privateKey = keyPair.privateKey;
      BigInt modulus = keyPair.modulus;

      await _firestore.collection("Users").doc(userCredential.user!.uid).set(
        {
          'uid': userCredential.user!.uid,
          'email': email,
          'publicKey': publicKey.toString(),
          'modulus': modulus.toString(),
          'videoCall': false,
          'videoTime': null,
        },
        SetOptions(merge: true),
      );

      await _secureStorage.write(
        key: 'privateKey_${userCredential.user!.uid}',
        value: privateKey.toString(),
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  Future<void> signOut() async {
    User? currentUser = getCurrentUser();

    if (currentUser != null) {
      String uid = currentUser.uid;

      try {
        // Step 1: Remove user's secure storage key
        await _secureStorage.delete(key: 'privateKey_$uid');

        // Step 2: Delete user from Firestore
        await _firestore.collection('Users').doc(uid).delete();

        // Step 3: Delete all chat rooms where the user is involved
        QuerySnapshot chatRoomsSnapshot = await _firestore
            .collection('chat_rooms')
            .where('participants', arrayContains: uid)
            .get();

        for (QueryDocumentSnapshot chatRoomDoc in chatRoomsSnapshot.docs) {
          String chatRoomId = chatRoomDoc.id;

          // Delete the entire chat room document (including messages subcollection)
          await _firestore.collection('chat_rooms').doc(chatRoomId).delete();
        }

        // Step 4: Delete Firebase Authentication user account
        await currentUser.delete();

        // Step 5: Sign out user
        await _auth.signOut();
      } on FirebaseAuthException catch (e) {
        throw Exception("Error during sign out: ${e.message}");
      } catch (e) {
        throw Exception("An error occurred during sign out: $e");
      }
    } else {
      throw Exception("No user is currently signed in.");
    }
  }

  // Future<UserCredential> signInWithEmailPassword(String email, String password) async {
  //   try {
  //     // Sign user in
  //     UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);

  //     String uid = userCredential.user!.uid;
  //     // Public key is already stored in Firestore during signup

  //     // Get private key from secure storage
  //     String? privateKeyString = await _secureStorage.read(key: 'privateKey_$uid');
  //     BigInt privateKey = BigInt.parse(privateKeyString ?? '0');

  //     // RSA modulus should also be retrieved from Firestore
  //     DocumentSnapshot userDoc = await _firestore.collection("Users").doc(uid).get();
  //     BigInt modulus = BigInt.parse(userDoc['modulus']);
  //     BigInt publicKey = BigInt.parse(userDoc['publicKey']);

  //     // Decrypt or encrypt as needed using public and private keys

  //     return userCredential;
  //   } on FirebaseAuthException catch (e) {
  //     throw Exception(e.code);
  //   }
  // }
}
