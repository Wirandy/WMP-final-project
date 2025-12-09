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

  // Fungsi Tambah Teman
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

  // [BARU] Fungsi Hapus Teman
  void _removePartner(String currentUid, String targetUid, String targetName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Anggota?"),
        content: Text("Yakin ingin menghapus $targetName dari grup kolaborasi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Tutup dialog
              try {
                await context.read<FirestoreService>().removeCollaborator(currentUid, targetUid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$targetName berhasil dihapus.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus: $e')),
                  );
                }
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Grup Kolaborasi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<UserModel?>(
        stream: firestoreService.getUserStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final user = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bagian Input Email
                const Text("Tambah Anggota Baru", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: "Masukkan email teman...",
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addPartner,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Undang"),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 20),

                // Judul List
                Row(
                  children: [
                    const Icon(Icons.group, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text("Anggota Grup (${user.collaborators.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 15),

                // List Anggota (Menggunakan FutureBuilder untuk ambil detail teman)
                Expanded(
                  child: user.collaborators.isEmpty
                      ? _buildEmptyState()
                      : FutureBuilder<List<UserModel>>(
                    future: firestoreService.getUsersByIds(user.collaborators),
                    builder: (context, snapFriends) {
                      if (snapFriends.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final friends = snapFriends.data ?? [];

                      return ListView.separated(
                        itemCount: friends.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0,2))],
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.purple.shade50,
                                child: Text(
                                  (friend.displayName ?? friend.email)[0].toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                                ),
                              ),
                              title: Text(friend.displayName ?? "Tanpa Nama", style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(friend.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                // Panggil fungsi hapus saat ditekan
                                onPressed: () => _removePartner(user.uid, friend.uid, friend.displayName ?? friend.email),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_disabled, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Belum ada anggota grup", style: TextStyle(color: Colors.grey, fontSize: 16)),
          const Text("Undang teman lewat email di atas!", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}