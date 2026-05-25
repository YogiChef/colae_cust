// ChatPage.dart - เพิ่มฟีเจอร์ส่งรูปภาพ (ถ่าย/เลือกจากแกลเลอรี)
// ignore_for_file: avoid_returning_null_for_void, unnecessary_underscores

import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // เพิ่ม
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends StatefulWidget {
  final String vendorId;
  final String buyerId;
  final String proId;
  final String proName;

  const ChatPage({
    super.key,
    required this.vendorId,
    required this.buyerId,
    required this.proId,
    required this.proName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late Stream<QuerySnapshot> _chatStream;
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  String _buyerName = 'Buyer';
  String _buyerPhoto = '';
  String _vendorPhoto = '';

  @override
  void initState() {
    super.initState();
    _chatStream = FirebaseFirestore.instance
        .collection('chats')
        .where('buyerId', isEqualTo: widget.buyerId)
        .where('vendorId', isEqualTo: widget.vendorId)
        .where('proId', isEqualTo: widget.proId)
        .orderBy('chatDate', descending: false)
        .snapshots();

    _chatSubscription = _chatStream.listen((snapshot) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    _loadParticipantData();
  }

  Future<void> _loadParticipantData() async {
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('buyers').doc(widget.buyerId).get(),
      FirebaseFirestore.instance
          .collection('vendors')
          .doc(widget.vendorId)
          .get(),
    ]);
    if (!mounted) return;
    final buyerData = results[0].data() ?? {};
    final vendorData = results[1].data() ?? {};
    _buyerName = buyerData['fullName'] ?? 'Buyer';
    _buyerPhoto = buyerData['profileImage'] ?? '';
    _vendorPhoto = vendorData['image'] ?? '';
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendTextMessage() async {
    final String message = _messageController.text.trim();
    if (message.isEmpty) return;

    await _sendMessageToFirestore(message: message, messageType: 'text');
    _messageController.clear();
    _focusNode.unfocus();
  }

  Future<void> _sendImageMessage({required ImageSource source}) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (pickedFile == null) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังบีบอัดและอัพโหลดรูปภาพ...')),
        );
      }

      Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
        pickedFile.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes == null || compressedBytes.isEmpty) {
        throw Exception('บีบอัดภาพไม่สำเร็จ');
      }

      final String fileName =
          'chats/${widget.buyerId}_${widget.vendorId}_${widget.proId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(
        fileName,
      );

      final UploadTask uploadTask = storageRef.putData(compressedBytes);
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await _sendMessageToFirestore(
        imageUrl: downloadUrl,
        messageType: 'image',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ส่งรูปภาพสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัพโหลดรูปภาพล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessageToFirestore({
    String message = '',
    String? imageUrl,
    required String messageType,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('chats').add({
        'proId': widget.proId,
        'proName': widget.proName,
        'buyerName': _buyerName,
        'buyerPhoto': _buyerPhoto,
        'vendorPhoto': _vendorPhoto,
        'buyerId': widget.buyerId,
        'vendorId': widget.vendorId,
        'message': message,
        'imageUrl': imageUrl,
        'messageType': messageType,
        'senderId': FirebaseAuth.instance.currentUser!.uid,
        'chatDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ส่งข้อความล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe) {
    final String? imageUrl = data['imageUrl'] as String?;
    final String? messageText = data['message'] as String?;

    final bool hasImage =
        imageUrl != null && imageUrl.isNotEmpty && imageUrl.trim() != '';

    Widget content;

    if (hasImage) {
      content = InkWell(
        onTap: () {
          final String orderId = data['orderId']?.toString() ?? 'ไม่ระบุ';
          _zoomSlip(imageUrl, orderId);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            height: 0.35.sh,
            width: 0.5.sw,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 200.h,
              color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported),
          ),
        ),
      );
    } else if (messageText != null && messageText.trim().isNotEmpty) {
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        child: Text(
          messageText,
          style: TextStyle(
            fontSize: 15.sp,
            color: isMe ? Colors.white : Colors.black87,
            height: 1.4,
          ),
        ),
      );
    }
    // fallback
    else {
      content = Padding(
        padding: EdgeInsets.all(12.w),
        child: Text(
          '[ไม่สามารถแสดงข้อความนี้ได้]',
          style: TextStyle(
            fontSize: 13.sp,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxWidth: 0.75.sw),
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isMe ? mainColor : Colors.grey[300],
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.proName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.phone), onPressed: () {})],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data?.docs ?? [];
                return ListView.builder(
                  reverse: false,
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final bool isMe =
                        data['senderId'] ==
                        FirebaseAuth.instance.currentUser!.uid;
                    return Padding(
                      padding: EdgeInsets.only(top: 8.h, right: 20.w),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(width: 12.w),
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 16.r,
                              backgroundImage: CachedNetworkImageProvider(
                                data['vendorPhoto'] ?? '',
                              ),
                            ),
                            SizedBox(width: 4.w),
                          ],
                          Flexible(child: _buildMessageBubble(data, isMe)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input bar + ปุ่มส่งรูป
          SafeArea(
            child: Container(
              height: 60.h,
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: mainColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(20),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.image_outlined,
                      color: Colors.white,
                      size: 24.r,
                    ),
                    onPressed: () => _showImageSourceDialog(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: null,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) _sendTextMessage();
                      },
                      decoration: InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7.r),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7.r),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7.r),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 0.h,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  FloatingActionButton(
                    heroTag: 'chat_rider_fab',
                    onPressed: _sendTextMessage,
                    mini: true,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.send, color: mainColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูป'),
              onTap: () {
                Navigator.pop(context);
                _sendImageMessage(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากแกลเลอรี'),
              onTap: () {
                Navigator.pop(context);
                _sendImageMessage(source: ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _zoomSlip(String url, String orderId) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'OrderID: $orderId',
              style: styles(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          body: InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 50, color: Colors.red),
                      SizedBox(height: 16),
                      Text('ไม่สามารถโหลดภาพได้'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
