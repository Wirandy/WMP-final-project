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
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _message = '';
  UserModel? _foundUser;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    setState(() {
      _isLoading = true;
      _message = '';
      _foundUser = null;
    });

    try {
      final user = await context.read<FirestoreService>().searchUserByEmail(_emailController.text.trim());
      setState(() {
        _foundUser = user;
        if (user == null) {
          _message = 'User not found';
        }
      });
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRequest() async {
    if (_foundUser == null) return;
    setState(() => _isLoading = true);
    try {
      await context.read<FirestoreService>().sendCollaborationRequest(_foundUser!.uid);
      setState(() {
        _message = 'Request sent to ${_foundUser!.email}';
        _foundUser = null;
        _emailController.clear();
      });
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptRequest(String requesterUid) async {
    setState(() => _isLoading = true);
    try {
      await context.read<FirestoreService>().acceptCollaborationRequest(requesterUid);
      setState(() => _message = 'Connected successfully!');
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectRequest() async {
    setState(() => _isLoading = true);
    try {
      await context.read<FirestoreService>().rejectCollaborationRequest();
      setState(() => _message = 'Request rejected');
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<FirestoreService>();
    
    return Scaffold(
      appBar: AppBar(title: const Text('Collaboration')),
      body: StreamBuilder<UserModel?>(
        stream: firestoreService.getUserStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentUser = snapshot.data;
          if (currentUser == null) return const Center(child: Text('Error loading user'));

          if (currentUser.partnerId != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  const Text('You are connected with a partner!'),
                  const SizedBox(height: 8),
                  FutureBuilder<UserModel?>(
                    future: firestoreService.getUser(currentUser.partnerId!),
                    builder: (context, partnerSnapshot) {
                      if (partnerSnapshot.hasData) {
                        return Text('Partner: ${partnerSnapshot.data!.email}');
                      }
                      return const Text('Loading partner info...');
                    },
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (currentUser.pendingRequestFrom != null) ...[
                  Card(
                    color: Colors.orange.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Pending Request', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          FutureBuilder<UserModel?>(
                            future: firestoreService.getUser(currentUser.pendingRequestFrom!),
                            builder: (context, reqSnapshot) {
                              if (reqSnapshot.hasData) {
                                return Text('${reqSnapshot.data!.email} wants to connect.');
                              }
                              return const Text('Loading requester info...');
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: _isLoading ? null : () => _acceptRequest(currentUser.pendingRequestFrom!),
                                child: const Text('Accept'),
                              ),
                              OutlinedButton(
                                onPressed: _isLoading ? null : _rejectRequest,
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                const Text('Invite Partner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Partner Email',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _isLoading ? null : _searchUser,
                    ),
                  ),
                ),
                if (_foundUser != null) ...[
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(_foundUser!.displayName ?? 'No Name'),
                    subtitle: Text(_foundUser!.email),
                    trailing: ElevatedButton(
                      onPressed: _isLoading ? null : _sendRequest,
                      child: const Text('Send Request'),
                    ),
                  ),
                ],
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_message, style: TextStyle(color: _message.startsWith('Error') ? Colors.red : Colors.green)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
