import 'package:chatapp_flutter/components/chat_bubble.dart';
import 'package:chatapp_flutter/components/my_textfield.dart';
import 'package:chatapp_flutter/services/auth/auth_service.dart';
import 'package:chatapp_flutter/services/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatapp_flutter/pages/video_call.dart';
import 'package:flutter/material.dart';
import 'package:chatapp_flutter/models/message.dart';

class ChatPage extends StatefulWidget {
  final String receiverEmail;
  final String receiverID;

  ChatPage({
    super.key,
    required this.receiverEmail,
    required this.receiverID,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  //text controller
  final TextEditingController _messageController = TextEditingController();

  //chat & auth services
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  //for textfield focus
  FocusNode myFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    //add listener to focus node
    myFocusNode.addListener(() {
      if (myFocusNode.hasFocus) {
        //cause a delay so that the keyboard has time to show up
        //then the mount of remaining space will be calculated,
        //then scroll down
        Future.delayed(
          const Duration(milliseconds: 500),
          () => scrollDown(),
        );
      }
    });

    //wait a bit for listview to be built, then scroll to bottom
    Future.delayed(
      const Duration(milliseconds: 500),
      () => scrollDown(),
    );
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    _messageController.dispose();
    super.dispose();
  }

  //scroll controller
  final ScrollController _scrollController = ScrollController();
  void scrollDown() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(seconds: 1),
      curve: Curves.fastOutSlowIn,
    );
  }

  // void scrollDown2() {
  //   _scrollController.jumpTo(
  //     _scrollController.position.maxScrollExtent,
  //   );
  // }

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      String plainTextMessage = _messageController.text;

      // Send the encrypted message
      await _chatService.sendMessage(widget.receiverID, plainTextMessage);

      // Clear the text field
      _messageController.clear();

      // Refresh the chat page
      setState(() {});

      // Delay scrolling until the page rebuilds
      // Future.delayed(
      //   const Duration(milliseconds: 600),
      //   () => scrollDown2(),
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverEmail),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
        actions: [
          // Audio call icon
          IconButton(
            icon: const Icon(Icons.call, color: Colors.grey),
            onPressed: () {
              // Handle audio call action here
              print('Audio call initiated');
            },
          ),
          // Video call icon
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.grey),
            onPressed: () async {
              try {
                // Update the receiver's videoCall property to true
                await FirebaseFirestore.instance
                    .collection('Users')
                    .doc(widget.receiverID)
                    .update({
                  'videoCall': true,
                  'videoTime': Timestamp.now(),
                });

                // Navigate to the video call page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          VideoCall(receiverID: widget.receiverID)),
                );
              } catch (e) {
                // Handle errors gracefully
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to initiate video call: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          //display all messages
          Expanded(child: _buildMessageList()),

          //user input
          _buildUserInput(),
        ],
      ),
    );
  }

  // build message list
  Widget _buildMessageList() {
    String senderID = _authService.getCurrentUser()!.uid;

    return FutureBuilder<Stream<List<Message>>>(
      future: _chatService.getMessages(widget.receiverID),
      builder: (context, futureSnapshot) {
        if (futureSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (futureSnapshot.hasError) {
          return Center(child: Text("Error: ${futureSnapshot.error}"));
        }
        if (!futureSnapshot.hasData) {
          return const Center(child: Text("No messages found"));
        }

        // Use the stream returned by the FutureBuilder
        return StreamBuilder<List<Message>>(
          stream: futureSnapshot.data,
          builder: (context, streamSnapshot) {
            if (streamSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (streamSnapshot.hasError) {
              return Center(child: Text("Error: ${streamSnapshot.error}"));
            }
            if (!streamSnapshot.hasData || streamSnapshot.data!.isEmpty) {
              return const Center(child: Text("No messages yet"));
            }

            // Snap to the bottom when new messages arrive
            WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());

            // Render the list of messages
            List<Message> messages = streamSnapshot.data!;
            return ListView.builder(
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                Message message = messages[index];
                return _buildMessageItem(message);
              },
            );
          },
        );
      },
    );
  }

  // build message item
  Widget _buildMessageItem(Message message) {
    // is current user
    bool isCurrentUser = message.senderID == _authService.getCurrentUser()!.uid;

    // align message to the right if sender is the current user, otherwise left
    var alignment =
        isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;

    return Container(
      alignment: alignment,
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message: message.message,
            isCurrentUser: isCurrentUser,
          ),
        ],
      ),
    );
  }

  //build message input
  Widget _buildUserInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 50.0),
      child: Row(
        children: [
          //textfield should take up most of the space
          Expanded(
            child: MyTextField(
              controller: _messageController,
              hintText: "Type a message",
              obscureText: false,
              focusNode: myFocusNode,
            ),
          ),

          //send button
          Container(
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            margin: const EdgeInsets.only(right: 25),
            child: IconButton(
              onPressed: sendMessage,
              icon: const Icon(
                Icons.arrow_upward,
                color: Colors.white,
              ),
            ),
          )
        ],
      ),
    );
  }
}
