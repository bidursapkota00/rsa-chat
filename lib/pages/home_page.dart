//import 'package:chatapp_flutter/auth/auth_service.dart';
import 'package:chatapp_flutter/components/my_drawer.dart';
import 'package:chatapp_flutter/components/user_tile.dart';
import 'package:chatapp_flutter/pages/chat_page.dart';
import 'package:chatapp_flutter/services/auth/auth_service.dart';
import 'package:chatapp_flutter/services/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chatapp_flutter/pages/video_call.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  //chat & auth service
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text("Home"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
      ),
      drawer: const MyDrawer(),
      body: Stack(
        children: [
          _buildUserList(),
          _buildIncomingCallListener(context),
        ],
      ),
    );
  }

  //build a list of users except for the current logged in user
  Widget _buildUserList() {
    return StreamBuilder(
      stream: _chatService.getUsersStream(),
      builder: (context, snapshot) {
        //error
        if (snapshot.hasError) {
          return const Text("Error");
        }

        //loading..
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading..");
        }

        //return list view
        return ListView(
          children: snapshot.data!
              .map<Widget>((userData) => _buildUserListItem(userData, context))
              .toList(),
        );
      },
    );
  }

  //build individual list tile for user
  Widget _buildUserListItem(
      Map<String, dynamic> userData, BuildContext context) {
    //display all users except current user
    if (userData["email"] != _authService.getCurrentUser()!.email) {
      return UserTile(
        text: userData["email"],
        onTap: () {
          //tapped on a user -> go to chat page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                receiverEmail: userData["email"],
                receiverID: userData["uid"],
              ),
            ),
          );
        },
      );
    } else {
      return Container();
    }
  }

  // Build a listener for incoming video calls
  Widget _buildIncomingCallListener(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(_authService.getCurrentUser()!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final bool videoCall = userData['videoCall'] ?? false;
        final Timestamp? videoTime = userData['videoTime'];

        if (videoCall &&
            videoTime != null &&
            DateTime.now().difference(videoTime.toDate()).inMinutes < 2) {
          // Show the incoming call dialog
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showIncomingCallDialog(context, userData['uid']);
          });
        }

        return const SizedBox.shrink();
      },
    );
  }

  void _showIncomingCallDialog(BuildContext context, String callerID) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Incoming Video Call"),
          content: const Text("You have an incoming video call."),
          actions: [
            TextButton(
              onPressed: () {
                // Decline the call
                FirebaseFirestore.instance
                    .collection('Users')
                    .doc(_authService.getCurrentUser()!.uid)
                    .update({'videoCall': false});
                Navigator.pop(context);
              },
              child: const Text("Decline"),
            ),
            ElevatedButton(
              onPressed: () {
                // Accept the call and navigate to VideoCall page
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => VideoCall(
                          receiverID: _authService
                              .getCurrentUser()!
                              .uid)), // Navigate to video call
                );
              },
              child: const Text("Accept"),
            ),
          ],
        );
      },
    );
  }
}
