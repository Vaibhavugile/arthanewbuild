import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // For UserProvider
import '../../providers/user_provider.dart';
import 'package:art/screens/billing_screen.dart';

class AddTable extends StatefulWidget {
  @override
  _AddTableState createState() => _AddTableState();
}

class _AddTableState extends State<AddTable> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _tableNumberController = TextEditingController();
  bool sidebarOpen = false;

  // Added isDarkMode state for AppBar theming
  bool isDarkMode = false; // You might want to pass this from a parent widget later for consistent theme management

  // Theme Colors copied from BranchDashboard
  final Color appBarGradientStart = Color(0xFFE0FFFF); // Muted light blue
  final Color appBarGradientMid = Color(0xFFBFEBFA); // Steel Blue
  final Color appBarGradientEnd = Color(0xFF87CEEB); // Dark Indigo


  @override
  void initState() {
    super.initState();
  }

  // Get the branchCode from UserProvider
  String? _getBranchCode() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    return userProvider.branchCode;
  }

  Future<void> _handleSubmit() async {
    final branchCode = _getBranchCode();
    if (_formKey.currentState!.validate() && branchCode != null) {
      try {
        // Reference to subcollection: tables/{branchCode}/tables
        CollectionReference tablesRef = FirebaseFirestore.instance
            .collection('tables')
            .doc(branchCode)
            .collection('tables');

        await tablesRef.add({
          'tableNumber': _tableNumberController.text,
          'branchCode': branchCode,
          'orders': [], // Initialize with an empty orders array
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Table added successfully!')),
        );

        // Optionally, navigate back after adding the table
        Navigator.pop(context);

      } catch (e) {
        print("Error adding table: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding table: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Removed backgroundColor and replaced with flexibleSpace for gradient/dark mode
        title: Text(
          'Add Table',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87), // Adjusted color based on dark mode
        ),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black87), // Adjusted color based on dark mode
        flexibleSpace: isDarkMode // Logic copied from BranchDashboard
            ? Container(
          color: Colors.grey[850],
        )
            : Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                appBarGradientStart,
                appBarGradientMid,
                appBarGradientEnd,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Add New Table', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _tableNumberController,
                    decoration: InputDecoration(labelText: 'Table Number / Counter Number'),
                    // keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a table number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _handleSubmit,
                    child: Text('Add Table'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}