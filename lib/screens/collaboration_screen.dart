import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../models/request_model.dart';

class CollaborationScreen extends StatefulWidget {
  const CollaborationScreen({super.key});

  @override
  State<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends State<CollaborationScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  void _sendRequest() async {
    if (_emailController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final firestoreService = context.read<FirestoreService>();
      final currentUser = await firestoreService.getUserStream().first;

      if (currentUser != null) {
        await firestoreService.sendCollaborationRequest(
          currentUser.uid,
          currentUser.email,
          _emailController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permintaan kolaborasi dikirim!')),
          );
          _emailController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _respondToRequest(RequestModel req, bool accept) async {
    try {
      final firestoreService = context.read<FirestoreService>();
      final currentUser = await firestoreService.getUserStream().first;
      if (currentUser == null) return;

      if (accept) {
        await firestoreService.acceptRequest(
          req.id,
          req.fromUid,
          currentUser.uid,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Permintaan diterima!")));
        }
      } else {
        await firestoreService.rejectRequest(req.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Permintaan ditolak.")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text("Grup Kolaborasi")),
      body: StreamBuilder<UserModel?>(
        stream: firestoreService.getUserStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final user = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1: KIRIM REQUEST
                const Text(
                  "Kirim Permintaan Kolaborasi",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "Email Teman",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _sendRequest,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text("Kirim"),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // SECTION 2: PERMINTAAN MASUK
                const Text(
                  "Permintaan Masuk:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<RequestModel>>(
                  stream: firestoreService.getIncomingRequests(user.email),
                  builder: (context, reqSnap) {
                    if (reqSnap.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    final requests = reqSnap.data ?? [];

                    if (requests.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          "Tidak ada permintaan baru.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        return Card(
                          color: Colors.blue.shade50,
                          child: ListTile(
                            leading: const Icon(
                              Icons.mail_outline,
                              color: Colors.blue,
                            ),
                            title: Text(req.fromEmail),
                            subtitle: const Text(
                              "Ingin berkolaborasi dengan Anda",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _respondToRequest(req, true),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _respondToRequest(req, false),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 20),

                // SECTION 3: ANGGOTA GRUP
                const Text(
                  "Anggota Grup Saat Ini:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: FutureBuilder<List<UserModel>>(
                    future: firestoreService.getUsersByIds(user.collaborators),
                    builder: (context, snapFriends) {
                      if (snapFriends.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final friends = snapFriends.data ?? [];

                      if (friends.isEmpty) {
                        return const Center(
                          child: Text("Belum ada anggota lain."),
                        );
                      }

                      return ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(friend.displayName ?? friend.email),
                              subtitle: Text(friend.email),
                              trailing: Text(
                                "Rp ${friend.balance.toStringAsFixed(0)}",
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
        },
      ),
    );
  }
}
