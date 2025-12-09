import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? initialType;
  const AddTransactionScreen({super.key, this.initialType});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _selectedCategory = 'Makan';
  String _type = 'expense';
  DateTime _selectedDate = DateTime.now();
  bool _isGroupTransaction = false; // <--- Variabel untuk Switch

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _type = widget.initialType!;
      if (_type == 'income') _selectedCategory = 'Gaji';
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap isi nominal!')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    CollectionReference transactions = FirebaseFirestore.instance.collection('transactions');

    try {
      await transactions.add({
        'userId': user.uid,
        'amount': double.parse(_amountController.text),
        'category': _selectedCategory,
        'description': _descController.text,
        'type': _type,
        'date': _selectedDate,
        'isGroup': _isGroupTransaction, // <--- Simpan status Grup/Pribadi
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data Berhasil Disimpan')));
        Navigator.pop(context);
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_type == 'income' ? "Tambah Pemasukan" : "Catat Pengeluaran"),
        backgroundColor: _type == 'income' ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pilihan Tipe
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Pengeluaran'), icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(value: 'income', label: Text('Pemasukan'), icon: Icon(Icons.arrow_upward)),
                ],
                selected: {_type},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _type = newSelection.first;
                    if (_type == 'income') _selectedCategory = 'Gaji';
                    else _selectedCategory = 'Makan';
                  });
                },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return _type == 'expense' ? Colors.red.shade100 : Colors.green.shade100;
                    }
                    return null;
                  }),
                ),
              ),
              const SizedBox(height: 20),

              // SWITCH BARU: TRANSAKSI GRUP ATAU PRIBADI
              SwitchListTile(
                title: const Text("Transaksi Grup?", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_isGroupTransaction
                    ? "Akan masuk ke Saldo Bersama"
                    : "Hanya masuk ke Saldo Pribadi"),
                value: _isGroupTransaction,
                activeColor: Colors.blue,
                onChanged: (bool value) {
                  setState(() {
                    _isGroupTransaction = value;
                  });
                },
              ),
              const Divider(),
              const SizedBox(height: 10),

              // Input Nominal
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Nominal (Rp)",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 15),

              // Input Tanggal
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Transaksi',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Pilihan Kategori
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Kategori",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _type == 'expense'
                    ? ['Makan', 'Transport', 'Belanja', 'Tagihan', 'Lainnya'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList()
                    : ['Gaji', 'Bonus', 'Investasi', 'Lainnya'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 15),

              // Input Keterangan
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: "Keterangan",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 25),

              ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _type == 'expense' ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("SIMPAN DATA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}