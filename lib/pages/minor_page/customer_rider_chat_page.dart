// customer_rider_chat_page.dart
// หน้าแชทสำหรับลูกค้า (Customer) คุยกับ Rider
// ใช้ collection 'rider_chats' เดียวกับฝั่ง Rider เพื่อ realtime ทั้งสองทาง

// ignore_for_file: use_build_context_synchronously, avoid_print, unnecessary_underscores

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

class CustomerRiderChatPage extends StatefulWidget {
  final String orderId;
  final String riderId; // riderId จาก order
  final String riderName; // ชื่อ rider (ถ้ามีจาก order หรือดึง realtime)

  const CustomerRiderChatPage({
    super.key,
    required this.orderId,
    required this.riderId,
    required this.riderName,
  });

  @override
  State<CustomerRiderChatPage> createState() => _CustomerRiderChatPageState();
}

class _CustomerRiderChatPageState extends State<CustomerRiderChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late Stream<QuerySnapshot> _chatStream;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  String customerName = 'ลูกค้า';
  String customerPhoto = '';
  String riderDisplayName = 'ไรเดอร์';
  String riderDisplayPhoto = '';
  StreamSubscription<DocumentSnapshot>? _riderSubscription;
  StreamSubscription<QuerySnapshot>? _chatSubscription;

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
    _listenToRiderData();
    _chatStream = firestore
        .collection('rider_chats')
        .where('orderId', isEqualTo: widget.orderId)
        .orderBy('chatDate', descending: true)
        .snapshots();

    // Store subscription so it can be cancelled in dispose()
    _chatSubscription = _chatStream.listen((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _riderSubscription?.cancel();
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerData() async {
    final uid = auth.currentUser!.uid;
    final doc = await firestore.collection('buyers').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        customerName = data['fullName']?.toString() ?? 'ลูกค้า';
        customerPhoto = data['profileImage']?.toString() ?? '';
      });
    }
  }

  void _listenToRiderData() {
    if (widget.riderId.isEmpty) {
      return;
    }

    _riderSubscription = firestore
        .collection('riders')
        .doc(widget.riderId)
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            final data = doc.data()!;
            final String name =
                data['fullName']?.toString() ?? widget.riderName;
            final String photo = data['facePhotoUrl']?.toString() ?? '';

            print(
              'DEBUG: อัพเดต rider realtime - ชื่อ: $name - รูป: $photo (มีรูป: ${photo.isNotEmpty})',
            );

            setState(() {
              riderDisplayName = name;
              riderDisplayPhoto = photo;
            });
          } else {
            setState(() {
              riderDisplayName = widget.riderName;
            });
          }
        }, onError: (e) {});
  }

  Future<void> _sendTextMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    await _sendMessage(message: message, messageType: 'text');
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('กำลังอัพโหลดรูปภาพ...')));

    try {
      final String fileName =
          'rider_chats/${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child(fileName);
      final UploadTask uploadTask = ref.putFile(File(pickedFile.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await _sendMessage(imageUrl: downloadUrl, messageType: 'image');

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ส่งรูปภาพสำเร็จ')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัพโหลดล้มเหลว: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendMessage({
    String message = '',
    String? imageUrl,
    required String messageType,
  }) async {
    await firestore.collection('rider_chats').add({
      'orderId': widget.orderId,
      'riderId': widget.riderId,
      'buyerId': auth.currentUser!.uid,
      'buyerName': customerName,
      'buyerPhoto': customerPhoto,
      'riderName': widget.riderName,
      'message': message,
      'imageUrl': imageUrl,
      'messageType': messageType,
      'senderId': auth.currentUser!.uid, // customer = buyer uid
      'chatDate': FieldValue.serverTimestamp(),
    });
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe) {
    final String? imageUrl = data['imageUrl'] as String?;
    final String? text = data['message'] as String?;

    Widget content;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      content = InkWell(
        onTap: () => _zoomImage(imageUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            height: 0.35.sh,
            width: 0.5.sw,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (_, __, ___) =>
                const Icon(Icons.broken_image, size: 50, color: Colors.red),
          ),
        ),
      );
    } else if (text != null && text.trim().isNotEmpty) {
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Text(
          text,
          style: styles(
            fontSize: 14.sp,
            color: isMe ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      content = const Text('[ไม่มีข้อความ]');
    }

    return Container(
      constraints: BoxConstraints(maxWidth: 0.75.sw),
      decoration: BoxDecoration(
        color: isMe
            ? mainColor
            : Colors.grey.shade200, // สีฝั่งลูกค้าเป็นน้ำเงิน
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          riderDisplayName,
          style: styles(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final bool isMe = data['senderId'] == auth.currentUser!.uid;

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 4.h,
                        horizontal: 8.w,
                      ),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe)
                            CircleAvatar(
                              radius: 16.r,
                              backgroundColor: Colors.green,
                              backgroundImage: riderDisplayPhoto.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      riderDisplayPhoto,
                                    )
                                  : null,
                              child: riderDisplayPhoto.isEmpty
                                  ? Text(
                                      riderDisplayName.isNotEmpty
                                          ? riderDisplayName[0].toUpperCase()
                                          : 'R',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          if (!isMe) SizedBox(width: 8.w),
                          Flexible(child: _buildMessageBubble(data, isMe)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withAlpha(50), blurRadius: 5),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.image_outlined, color: mainColor),
                    onPressed: _showImageSourceDialog,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 6.h,
                        ),
                      ),
                      onSubmitted: (_) => _sendTextMessage(),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: mainColor,
                    onPressed: _sendTextMessage,
                    child: const Icon(Icons.send, color: Colors.white),
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

  void _zoomImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('รูปภาพในแชท'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                placeholder: (_, __) => const CircularProgressIndicator(),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.error, size: 60, color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
