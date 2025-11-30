import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Pastikan ini ada (biasanya sudah dipasang Angel)

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _selectedCategory = 'Makan';
  String _type = 'expense';
  DateTime _selectedDate = DateTime.now(); 

  // Fungsi Memunculkan Kalender
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020), // Bisa pilih tanggal mundur sampai tahun 2020
      lastDate: DateTime.now(), // Tidak bisa pilih tanggal masa depan
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harap isi nominal!'))
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    CollectionReference transactions = FirebaseFirestore.instance.collection('transactions');

    try {
      await transactions.add({
        'userId': user.uid,
        'amount': int.parse(_amountController.text),
        'category': _selectedCategory,
        'description': _descController.text,
        'type': _type,
        'date': _selectedDate, // <-- PENTING: Pakai tanggal yang dipilih user
        'isShared': false,
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
      appBar: AppBar(title: const Text("Catat Transaksi")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Pilihan Tipe (Expense/Income)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Pengeluaran'), icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(value: 'income', label: Text('Pemasukan'), icon: Icon(Icons.arrow_upward)),
                ],
                selected: {_type},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _type = newSelection.first;
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

              // 2. Input Tanggal (Desain Baru)
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Transaksi',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('dd MMMM yyyy').format(_selectedDate), // Format cantik
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // 3. Input Nominal
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Nominal (Rp)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 15),

              // 4. Pilihan Kategori
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Kategori",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: ['Makan', 'Transport', 'Belanja', 'Tagihan', 'Gaji', 'Lainnya']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 15),

              // 5. Input Keterangan
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: "Keterangan",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 25),

              // 6. Tombol Simpan
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