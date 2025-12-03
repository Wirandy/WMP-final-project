import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';

class CollaborationScreen extends StatefulWidget {
  const CollaborationScreen({super.key});

  @override
  State<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends State<CollaborationScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  void _addPartner() async {
    if (_emailController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final firestoreService = context.read<FirestoreService>();
      final currentUser = await firestoreService.getUserStream().first;

      if (currentUser != null) {
        await firestoreService.addCollaborator(currentUser.uid, _emailController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Berhasil menambahkan anggota grup!')),
          );
          _emailController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final user = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tambah Anggota", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "Email Teman",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addPartner,
                      child: _isLoading ? const CircularProgressIndicator() : const Text("Add"),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Text("Anggota Grup Saat Ini:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // List Anggota
                Expanded(
                  child: FutureBuilder<List<UserModel>>(
                    future: firestoreService.getUsersByIds(user.collaborators),
                    builder: (context, snapFriends) {
                      if (snapFriends.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final friends = snapFriends.data ?? [];

                      if (friends.isEmpty) {
                        return const Center(child: Text("Belum ada anggota lain."));
                      }

                      return ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(friend.displayName ?? friend.email),
                              subtitle: Text(friend.email),
                              trailing: Text("Rp ${friend.balance.toStringAsFixed(0)}"),
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