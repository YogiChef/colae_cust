// ignore_for_file: avoid_print, use_build_context_synchronously, unnecessary_null_comparison

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sn_progress_dialog/progress_dialog.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:colae_cut/pages/minor_page/add_address.dart';

class AddressBook extends StatefulWidget {
  const AddressBook({super.key});

  @override
  State<AddressBook> createState() => _AddressBookState();
}

class _AddressBookState extends State<AddressBook> {
  @override
  Widget build(BuildContext context) {
    CollectionReference users = firestore.collection('buyers');
    final Stream<QuerySnapshot> addressStream = firestore
        .collection('buyers')
        .doc(auth.currentUser!.uid)
        .collection('address')
        .snapshots();
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: mainColor,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          'ที่อยู่ปัจจุบัน',
          style: styles(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: IconButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height * .15,
                  child: FutureBuilder<DocumentSnapshot>(
                    future: users.doc(auth.currentUser!.uid).get(),
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<DocumentSnapshot> snapshot,
                        ) {
                          if (snapshot.hasError) {
                            return const Text("Something went wrong");
                          }
                          if (snapshot.hasData && !snapshot.data!.exists) {
                            return const Text("Document does not exist");
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.done) {
                            Map<String, dynamic>? userDataMap =
                                snapshot.data!.data()
                                    as Map<
                                      String,
                                      dynamic
                                    >?; // FIXED: Null safe
                            if (userDataMap == null) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: width * 0.7,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: mainColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                      ),
                                      label: Text(
                                        'เพิ่มที่อยู่',
                                        style: styles(color: Colors.white),
                                      ),
                                      onPressed: () async {
                                        if (!mounted) return; // FIXED: Guard
                                        final result =
                                            await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => Address(
                                                  userData: userDataMap,
                                                ),
                                              ),
                                            );
                                        if (result == true && mounted) {
                                          Navigator.pop(context, true);
                                        }
                                      },
                                      icon: Icon(
                                        Icons.add,
                                        size: 24.r,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.orange,
                            ),
                          );
                        },
                  ),
                ),
              ),
              icon: Icon(Icons.add, size: 24.r, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: addressStream,
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return const Text('Something went wrong');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Material(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snapshot.data?.docs ?? []; // FIXED: Null safe
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'You have set \n\n an address yet !',
                      textAlign: TextAlign.center,
                      style: styles(
                        color: Colors.blueGrey,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var customer = docs[index];
                    Map<String, dynamic> data =
                        customer.data()
                            as Map<String, dynamic>; // FIXED: Safe cast
                    return Dismissible(
                      key: UniqueKey(),
                      onDismissed: (direction) async {
                        if (!mounted) return; // FIXED: Guard
                        await firestore.runTransaction((transaction) async {
                          DocumentReference docRf = firestore
                              .collection('buyers')
                              .doc(auth.currentUser!.uid)
                              .collection('address')
                              .doc(customer.id);
                          transaction.delete(docRf);
                        });

                        try {
                          DocumentReference userRef = firestore
                              .collection('buyers')
                              .doc(auth.currentUser!.uid);
                          CollectionReference addrColl = userRef.collection(
                            'address',
                          );

                          QuerySnapshot qs = await addrColl
                              .where('default', isEqualTo: true)
                              .limit(1)
                              .get();

                          if (qs.docs.isEmpty) {
                            await userRef.update({'address': ''});
                          } else {}
                        } catch (e) {
                          if (mounted) {
                            _showError('เกิดข้อผิดพลาดในการอัพเดทที่อยู่: $e');
                          }
                        }

                        if (mounted) setState(() {});
                      },
                      child: GestureDetector(
                        onTap: () async {
                          if (!mounted) return;
                          ProgressDialog? progress;
                          try {
                            progress = ProgressDialog(context: context);
                            progress.show(
                              max: 100,
                              msg: 'กำลังอัพเดทที่อยู่...',
                              msgColor: Colors.red,
                            );

                            for (var item in docs) {
                              if (!mounted) break;
                              await dfAddressFalse(item);
                            }
                            if (!mounted) {
                              progress.close();
                              return;
                            }
                            await dfAddressTrue(customer);
                            if (!mounted) {
                              progress.close();
                              return;
                            }
                            await updateProfile(customer);
                          } catch (e) {
                            if (mounted) {
                              _showError(
                                'เกิดข้อผิดพลาดในการอัพเดทที่อยู่: $e',
                              );
                            }
                          } finally {
                            if (progress != null && mounted) {
                              progress.close();
                              Future.delayed(
                                const Duration(milliseconds: 100),
                                () {
                                  if (mounted) {
                                    Navigator.pop(context, true);
                                  }
                                },
                              );
                            }
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Stack(
                            children: [
                              Card(
                                elevation: 5,
                                color: (data['default'] ?? false)
                                    ? Colors.purple.shade100
                                    : Colors.grey.shade200,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: ListTile(
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${data['fullName']} ',
                                        style: textstyles(
                                          height: 2,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                      Text(
                                        "${data['phone']}",
                                        style: textstyles(
                                          height: 1.2,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${data['address']} ',
                                        style: textstyles(
                                          height: 1.2,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                      Text(
                                        '${data['city']},  ${data['state']} ',
                                        style: textstyles(
                                          height: 1.2,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                      Text(
                                        "${data['country']}  ${data['zipcode']}",
                                        style: textstyles(
                                          height: 1.2,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                      if ((data['default'] ?? false))
                                        Center(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                            ),
                                            label: Text(
                                              'ยืนยัน',
                                              style: styles(
                                                color: Colors.white,
                                              ),
                                            ),
                                            onPressed: () async {
                                              if (!mounted) {
                                                return; // FIXED: Guard
                                              }
                                              ProgressDialog? progress =
                                                  ProgressDialog(
                                                    context: context,
                                                  );
                                              try {
                                                progress.show(
                                                  max: 100,
                                                  msg: 'กำลังอัพเดทที่อยู่...',
                                                  msgColor: Colors.red,
                                                );

                                                for (var item in docs) {
                                                  if (!mounted) break;
                                                  await dfAddressFalse(item);
                                                }
                                                if (!mounted) {
                                                  progress.close();
                                                  return;
                                                }
                                                await dfAddressTrue(customer);
                                                if (!mounted) {
                                                  progress.close();
                                                  return;
                                                }
                                                await updateProfile(customer);
                                                // FIXED: Debug
                                              } catch (e) {
                                                if (mounted) {
                                                  _showError(
                                                    'เกิดข้อผิดพลาดในการอัพเดทที่อยู่: $e',
                                                  );
                                                }
                                              } finally {
                                                if (progress != null &&
                                                    mounted) {
                                                  progress.close();
                                                  Future.delayed(
                                                    const Duration(
                                                      milliseconds: 100,
                                                    ),
                                                    () {
                                                      if (mounted) {
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        );
                                                      }
                                                    },
                                                  );
                                                }
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.padding,
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 10,
                                child: (data['default'] ?? false)
                                    ? IconButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        icon: const Icon(
                                          Icons.home,
                                          color: Colors.green,
                                        ),
                                      )
                                    : const SizedBox(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future dfAddressFalse(dynamic item) async {
    if (!mounted) return; // FIXED: Guard
    await firestore.runTransaction((transaction) async {
      DocumentReference dRf = firestore
          .collection('buyers')
          .doc(auth.currentUser!.uid)
          .collection('address')
          .doc(item.id);
      transaction.update(dRf, {'default': false});
    });
  }

  Future dfAddressTrue(QueryDocumentSnapshot<Object?> customer) async {
    if (!mounted) return; // FIXED: Guard
    await firestore.runTransaction((transaction) async {
      DocumentReference dRf = firestore
          .collection('buyers')
          .doc(auth.currentUser!.uid)
          .collection('address')
          .doc(customer['addressId']);
      transaction.update(dRf, {'default': true});
    });
  }

  Future updateProfile(QueryDocumentSnapshot<Object?> customer) async {
    if (!mounted) return; // FIXED: Guard
    await firestore.runTransaction((transaction) async {
      DocumentReference dRf = firestore
          .collection('buyers')
          .doc(auth.currentUser!.uid);
      transaction.update(dRf, {
        'phone': customer['phone'],
        'address': customer['address'],
        'city': customer['city'],
        'state': customer['state'],
        'country': customer['country'],
        'zipcode': customer['zipcode'],
      });
    });
    // FIXED: Debug update
  }

  void showprogress() {
    if (!mounted) return; // FIXED: Guard
    ProgressDialog progress = ProgressDialog(context: context);
    progress.show(max: 100, msg: 'please wait..', msgColor: Colors.red);
  }

  void hideprogress() {
    if (!mounted) return; // FIXED: Guard
    ProgressDialog progress = ProgressDialog(context: context);
    progress.close();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}
