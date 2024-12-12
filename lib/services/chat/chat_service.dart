import 'package:chatapp_flutter/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatapp_flutter/services/encrypt/rsa.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ChatService {
  //get instance of firestore & auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //get user stream
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        //go through each individual user
        final user = doc.data();

        //return user
        return user;
      }).toList();
    });
  }

  //send message
  Future<void> sendMessage(String receiverID, String message) async {
    // Get current user info
    final String currentUserID = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    // Fetch the receiver's public key and modulus
    DocumentSnapshot receiverSnapshot =
        await _firestore.collection("Users").doc(receiverID).get();

    if (!receiverSnapshot.exists) {
      throw Exception("Receiver not found");
    }

    Map<String, dynamic> receiverData =
        receiverSnapshot.data() as Map<String, dynamic>;
    BigInt publicKey = BigInt.parse(receiverData['publicKey']);
    BigInt modulus = BigInt.parse(receiverData['modulus']);

    // Encrypt the message using the receiver's public key
    RSA rsa = RSA();
    String encryptedMessage = rsa.encrypt(message, publicKey, modulus);

    // Create a new message object with the encrypted message
    Message newMessage = Message(
      senderID: currentUserID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: encryptedMessage, // Encrypted message
      timestamp: timestamp,
    );

    // Construct chat room ID for the two users (sorted to ensure uniqueness)
    List<String> ids = [currentUserID, receiverID];
    ids.sort(); // Sort the IDs to ensure the chatroomID is consistent
    String chatroomID = ids.join('_');

    // Add the new encrypted message to the database
    await _firestore
        .collection("chat_rooms")
        .doc(chatroomID)
        .collection("messages")
        .add(newMessage.toMap());
  }

  //get messages
  Future<Stream<List<Message>>> getMessages(String otherUserID) async {
    // Get the current user's ID
    final String currentUserID = _auth.currentUser!.uid;

    // Retrieve the private key of the current user from secure storage
    final FlutterSecureStorage secureStorage = FlutterSecureStorage();
    String? privateKeyString =
        await secureStorage.read(key: 'privateKey_$currentUserID');

    if (privateKeyString == null) {
      throw Exception("Private key not found for the current user");
    }

    // Parse the private key
    BigInt privateKey = BigInt.parse(privateKeyString);

    // Retrieve the current user's modulus from Firestore
    DocumentSnapshot currentUserDoc =
        await _firestore.collection('Users').doc(currentUserID).get();

    if (!currentUserDoc.exists ||
        !(currentUserDoc.data() as Map<String, dynamic>)
            .containsKey('modulus')) {
      throw Exception("Modulus not found for the current user");
    }

    // Parse the modulus of the current user
    BigInt modulus = BigInt.parse(currentUserDoc['modulus']);

    // Construct chat room ID for the two users (sorted to ensure uniqueness)
    List<String> ids = [currentUserID, otherUserID];
    ids.sort(); // Sort the IDs to ensure the chatroomID is consistent
    String chatRoomID = ids.join('_');

    // Stream the messages and decrypt them
    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        // Get the encrypted message data
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Decrypt the message using the current user's private key
        String encryptedMessage = data['message'];
        RSA rsa = RSA();

        // Decrypt the message
        String decryptedMessage =
            rsa.decrypt(encryptedMessage, privateKey, modulus);

        // Create the Message object with the decrypted message
        return Message(
          senderID: data['senderID'],
          senderEmail: data['senderEmail'],
          receiverID: data['receiverID'],
          message:
              "Decrypted: " + decryptedMessage, // Use the decrypted message
          timestamp: data['timestamp'],
        );
      }).toList();
    });
  }
}
