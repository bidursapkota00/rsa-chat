import 'package:chatapp_flutter/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatapp_flutter/services/encrypt/rsa.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  Future<void> _storeLocalMessage(String chatroomID, Message message) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Fetch existing messages from local storage
    List<String> messages = prefs.getStringList(chatroomID) ?? [];

    // Add the new message with the timestamp converted to milliseconds
    Map<String, dynamic> messageMap = message.toMap();
    messageMap['timestamp'] =
        message.timestamp.millisecondsSinceEpoch; // Convert Timestamp

    messages.add(jsonEncode(messageMap));

    // Save back to local storage
    await prefs.setStringList(chatroomID, messages);
  }

  Future<List<Message>> _getLocalMessages(String chatroomID) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Fetch existing messages from local storage
    List<String> messages = prefs.getStringList(chatroomID) ?? [];

    // Convert to Message objects
    return messages.map((e) {
      Map<String, dynamic> messageMap = jsonDecode(e);

      // Convert milliseconds back to Timestamp
      messageMap['timestamp'] =
          Timestamp.fromMillisecondsSinceEpoch(messageMap['timestamp']);

      return Message.fromMap(messageMap);
    }).toList();
  }

  // Send message
  Future<void> sendMessage(String receiverID, String message) async {
    final String currentUserID = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    // Fetch receiver's public key and modulus
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

    // Create a new message object
    Message newMessage = Message(
      senderID: currentUserID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: encryptedMessage,
      timestamp: timestamp,
    );

    // Construct chat room ID
    List<String> ids = [currentUserID, receiverID];
    ids.sort();
    String chatroomID = ids.join('_');

    // Save the message to Firestore
    await _firestore
        .collection("chat_rooms")
        .doc(chatroomID)
        .collection("messages")
        .add(newMessage.toMap());

    // Save unencrypted message to local storage
    Message localMessage = Message(
      senderID: currentUserID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: message, // Store plain text message locally
      timestamp: timestamp,
    );
    await _storeLocalMessage(chatroomID, localMessage);
  }

  // Get messages
  Future<Stream<List<Message>>> getMessages(String otherUserID) async {
    final String currentUserID = _auth.currentUser!.uid;

    // Retrieve private key
    final FlutterSecureStorage secureStorage = FlutterSecureStorage();
    String? privateKeyString =
        await secureStorage.read(key: 'privateKey_$currentUserID');

    if (privateKeyString == null) {
      throw Exception("Private key not found");
    }

    BigInt privateKey = BigInt.parse(privateKeyString);

    // Retrieve modulus
    DocumentSnapshot currentUserDoc =
        await _firestore.collection('Users').doc(currentUserID).get();

    if (!currentUserDoc.exists ||
        !(currentUserDoc.data() as Map<String, dynamic>)
            .containsKey('modulus')) {
      throw Exception("Modulus not found");
    }

    BigInt modulus = BigInt.parse(currentUserDoc['modulus']);

    // Construct chat room ID
    List<String> ids = [currentUserID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');

    // Fetch local messages
    List<Message> localMessages = await _getLocalMessages(chatRoomID);

    // Stream Firestore messages
    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots()
        .map((snapshot) {
      // Combine Firestore and local messages
      List<Message> messages = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        if (data['senderID'] == currentUserID) {
          // Return locally stored message for the current user
          return localMessages.firstWhere(
              (msg) =>
                  msg.timestamp.millisecondsSinceEpoch ==
                  data['timestamp'].millisecondsSinceEpoch,
              orElse: () => Message.fromMap(data));
        } else {
          // Decrypt message for messages from the other user
          RSA rsa = RSA();
          String decryptedMessage =
              rsa.decrypt(data['message'], privateKey, modulus);

          return Message(
            senderID: data['senderID'],
            senderEmail: data['senderEmail'],
            receiverID: data['receiverID'],
            message: decryptedMessage,
            timestamp: data['timestamp'],
          );
        }
      }).toList();

      return messages;
    });
  }
}
