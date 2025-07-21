import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:art/screens/MenuPage.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as serial;
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import 'package:art/screens/AddTable.dart';
import'package:art/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app.dart'; // Adjust path as needed if app.dart is in /lib


class BillingScreen extends StatefulWidget {
  @override
  _BillingScreenState createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late String branchCode;
  String branchName = ''; // Added to store branch name

  List<Map<String, dynamic>> tables = [];
  Map<String, dynamic>? selectedTable;
  String paymentMethod = '';
  String paymentStatus = '';
  String responsibleName = '';
  double discountPercentage = 0.0;

  bool isDarkMode = false; // Added for theme toggle

  // Theme Colors - Adopted from inventory_screen.dart
  final Color lightModeBackgroundColor = const Color(0xFFF0F2F5);
  final Color darkModeBackgroundColor = const Color(0xFF1E1E1E);
  final Color lightModeCardColor = Colors.white;
  final Color darkModeCardColor = const Color(0xFF2C2C2C);
  final Color lightModeTextColor = Colors.black87;
  final Color darkModeTextColor = Colors.white;
  final Color lightModeCardTextColor = Colors.grey.shade800;
  final Color darkModeCardTextColor = Colors.grey.shade200;
  final Color lightModeIconColor = Colors.grey.shade700;
  final Color darkModeIconColor = Colors.grey.shade400;
  final Color lightModeAppBarColor = Colors.white;
  final Color darkModeAppBarColor = const Color(0xFF2C2C2C);
  final Color fabColor = const Color(0xFFBFEBFA); // Used for primary buttons/FAB
  final Color filterChipSelectedColor = const Color(0xFFBFEBFA);
  final Color filterChipTextColor = Colors.black87;


  final BlueThermalPrinter bluetoothPrinter = BlueThermalPrinter.instance;
  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    branchCode = userProvider.branchCode!;
    fetchTables();
    fetchBranchDetails(); // Fetch branch details here
  }

  // New function to fetch branch details
  Future<void> fetchBranchDetails() async {
    try {
      final docSnapshot = await _db.collection('branches').doc(branchCode).get();
      if (docSnapshot.exists) {
        setState(() {
          branchName = docSnapshot.data()?['branchName'] ?? 'My Fine Dine';
        });
      }
      print("Fetched branch name: $branchName");
    } catch (e) {
      print("Error fetching branch details: $e");
      setState(() {
        branchName = 'My Fine Dine'; // Fallback
      });
    }
  }


  Future<void> fetchTables() async {
    try {
      final querySnapshot = await _db
          .collection('tables')
          .doc(branchCode)
          .collection('tables')
          .get();

      setState(() {
        tables = querySnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
            'orderStatus': 'Running Order',
          };
        }).toList();
      });
    } catch (e) {
      print("Error fetching tables: $e");
    }
  }
  // Connect to the Bluetooth printer
  // Connect to the Bluetooth printer
  Future<void> saveSelectedPrinter(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_printer_address', address);
  }
  Future<BluetoothDevice?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAddress = prefs.getString('saved_printer_address');
    if (savedAddress == null) return null;

    final devices = await bluetoothPrinter.getBondedDevices();
    final matches = devices.where((device) => device.address == savedAddress);
    return matches.isNotEmpty ? matches.first : null;

  }

  Future<void> connectToBluetoothPrinter() async {
    try {
      final devices = await bluetoothPrinter.getBondedDevices();
      if (devices.isEmpty) {
        Fluttertoast.showToast(msg: "No Bluetooth devices found!");
        return;
      }

      // Disconnect before connecting again to avoid stale socket
      await bluetoothPrinter.disconnect();
      await Future.delayed(const Duration(milliseconds: 300));

      await bluetoothPrinter.connect(devices.first);
      await Future.delayed(const Duration(seconds: 1));

      final connected = await bluetoothPrinter.isConnected ?? false;
      if (connected) {
        Fluttertoast.showToast(msg: "Connected to printer!");
      } else {
        Fluttertoast.showToast(msg: "Failed to connect to printer.");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error connecting to Bluetooth printer: $e");
    }
  }
  Future<BluetoothDevice?> showPrinterSelectionDialog(BuildContext context) async {
    final devices = await bluetoothPrinter.getBondedDevices();

    return showDialog<BluetoothDevice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select a printer'),
        content: SizedBox(
          height: 300,
          width: double.maxFinite,
          child: devices.isEmpty
              ? const Center(child: Text("No paired printers found"))
              : ListView.builder(
            itemCount: devices.length,
            itemBuilder: (_, index) {
              final device = devices[index];
              return ListTile(
                title: Text(device.name ?? 'Unknown'),
                subtitle: Text(device.address ?? 'N/A'),
                onTap: () => Navigator.of(dialogContext).pop(device), // ✅ Use dialogContext here
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(), // ✅ Use dialogContext here too
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }



  Future<bool> ensureConnected(BuildContext context) async {
    try {
      bool connected = await bluetoothPrinter.isConnected ?? false;
      if (connected) return true;

      BluetoothDevice? device = await getSavedPrinter();

      // If not saved, ask user to pick one
      if (device == null) {
        device = await showPrinterSelectionDialog(context);
        if (device == null) {
          Fluttertoast.showToast(msg: "Printer selection cancelled");
          return false;
        }
        await saveSelectedPrinter(device.address!);
      }

      await bluetoothPrinter.connect(device);
      await Future.delayed(const Duration(seconds: 1));
      connected = await bluetoothPrinter.isConnected ?? false;

      if (!connected) {
        Fluttertoast.showToast(msg: "Failed to connect to printer");
      }

      return connected;
    } catch (e) {
      Fluttertoast.showToast(msg: "Connection error: $e");
      return false;
    }
  }

  Future<BluetoothDevice?> _selectPrinter(BuildContext context) async {
    try {
      List<BluetoothDevice> devices = await bluetoothPrinter.getBondedDevices();

      if (devices.isEmpty) {
        Fluttertoast.showToast(msg: "No paired Bluetooth devices found.");
        return null;
      }

      return await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Select Printer"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return ListTile(
                    title: Text(device.name ?? "Unknown"),
                    subtitle: Text(device.address ?? ""),
                    onTap: () => Navigator.pop(context, device),
                  );
                },
              ),
            ),
          );
        },
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Error fetching paired devices: $e");
      return null;
    }
  }
// Modified printReceipt to accept branchName
  Future<void> printReceipt(BuildContext context, Map<String, dynamic> table) async {
    try {
      // Check if printer is already saved
      BluetoothDevice? device = await getSavedPrinter();

      // If not saved, show selection dialog
      if (device == null) {
        device = await showPrinterSelectionDialog(context);
        if (device == null) return; // User cancelled
        await saveSelectedPrinter(device.address!); // Save selection
      }

      // Try to connect
      await bluetoothPrinter.connect(device);
      await Future.delayed(const Duration(seconds: 1));

      final isConnected = await bluetoothPrinter.isConnected ?? false;
      if (!isConnected) {
        Fluttertoast.showToast(msg: "Failed to connect to printer.");
        return;
      }
      final orders = List<Map<String, dynamic>>.from(table['orders'] ?? []);
      final totalPrice = calculateTotalPrice(orders);
      final paymentMethod = table['paymentMethod'] ?? 'Cash';
      final dateTime = DateTime.now();
      final tableNumber = table['tableNumber'] ?? 'N/A';
      final orderStatus = table['orderStatus'] ?? 'N/A';

      bluetoothPrinter.printNewLine();

      // Header
      bluetoothPrinter.printCustom(branchName, 3, 1); // Use branchName here
      // bluetoothPrinter.printCustom("Branch: $branchCode", 1, 1);
      bluetoothPrinter.printNewLine();
      bluetoothPrinter.printCustom("Date: ${dateTime.toLocal().toString().split('.').first}", 1, 1);
      bluetoothPrinter.printNewLine();

      // Order Info
      bluetoothPrinter.printCustom("Table No: $tableNumber", 1, 0);
      // bluetoothPrinter.printCustom("Status: $orderStatus", 1, 0);
      // bluetoothPrinter.printCustom("Payment: $paymentMethod", 1, 0);
      bluetoothPrinter.printNewLine();

      // Item list header and separator lines (32 characters wide)
      bluetoothPrinter.printCustom("--------------------------------", 1, 1); // 32 hyphens
      // Manually format the header for a 32-character width
      bluetoothPrinter.printCustom("Item            Qty   Price   Total", 1, 0); // Exactly 32 characters
      bluetoothPrinter.printCustom("--------------------------------", 1, 1); // 32 hyphens

      // Define the maximum characters for the item name on a single line.
      const int maxNameLength = 14; // Adjusted to fit within 32 total characters including 1 space between columns.
      const int qtyColumnWidth = 3;
      const int priceColumnWidth = 6;
      const int totalColumnWidth = 6;

      // The effective content width of an item line (excluding leading/trailing spaces if any)
      const int dataLineContentWidth = maxNameLength + 1 + qtyColumnWidth + 1 + priceColumnWidth + 1 + totalColumnWidth; // 14 + 1 + 3 + 1 + 6 + 1 + 6 = 32

      for (var order in orders) {
        String productName = order['name'] ?? 'Unknown';
        final quantity = int.tryParse(order['quantity'].toString()) ?? 0;
        final price = double.tryParse(order['price'].toString()) ?? 0.0;
        final lineTotal = (quantity * price).toStringAsFixed(2).padLeft(totalColumnWidth);
        final qtyStr = quantity.toString().padLeft(qtyColumnWidth);
        final priceStr = price.toStringAsFixed(2).padLeft(priceColumnWidth);

        // Check if the product name is too long and needs wrapping
        if (productName.length > maxNameLength) {
          // Print the first part of the name with quantity, price, and total
          String firstLineName = productName.substring(0, maxNameLength);
          String remainingName = productName.substring(maxNameLength);

          // Construct the first line: Name (padded) + space + Qty + space + Price + space + Total
          String line = "${firstLineName.padRight(maxNameLength)} ${qtyStr} ${priceStr} ${lineTotal}";
          bluetoothPrinter.printCustom(line, 1, 0); // Use ALIGN_LEFT and rely on manual padding

          // Print subsequent lines for the remaining part of the name
          // These lines will fill the full 'totalReceiptWidth' (32 chars)
          const int wrapLineLength = 32; // Max characters for wrapped lines
          while (remainingName.isNotEmpty) {
            String part = remainingName.substring(0, remainingName.length > wrapLineLength ? wrapLineLength : remainingName.length);
            bluetoothPrinter.printCustom(part.padRight(wrapLineLength), 1, 0); // Pad to ensure full line width
            remainingName = remainingName.substring(part.length);
          }
        } else {
          // If the name fits, print it normally, padded to align
          final name = productName.padRight(maxNameLength);
          // Construct the line: Name (padded) + space + Qty + space + Price + space + Total
          String line = "${name} ${qtyStr} ${priceStr} ${lineTotal}"; // This will be dataLineContentWidth (32) chars
          bluetoothPrinter.printCustom(line, 1, 0); // Use ALIGN_LEFT and rely on manual padding
        }
        bluetoothPrinter.printNewLine(); // Add a new line after each product
      }

      bluetoothPrinter.printCustom("--------------------------------", 1, 1);

      // Totals Section
      String subtotalLabel = "Subtotal";
      String subtotalAmount = totalPrice.toStringAsFixed(2).padLeft(totalColumnWidth);

      int spacesNeeded = dataLineContentWidth - subtotalLabel.length - subtotalAmount.length;
      String subtotalLine = subtotalLabel + " " * spacesNeeded + subtotalAmount;

      bluetoothPrinter.printCustom(subtotalLine, 1, 0);
      bluetoothPrinter.printNewLine();

      // Footer
      bluetoothPrinter.printCustom("--------------------------------", 1, 1);
      bluetoothPrinter.printCustom("Thank you for dining with us!", 1, 1);
      bluetoothPrinter.printCustom("Feedback? 1800-123-456", 1, 1);
      bluetoothPrinter.printCustom("Visit again!", 1, 1);
      bluetoothPrinter.printCustom("--------------------------------", 1, 1);
      bluetoothPrinter.printNewLine();

      await bluetoothPrinter.disconnect();
    } catch (e) {
      Fluttertoast.showToast(msg: "Error printing receipt: $e");
    }
  }






  double calculateTotalPrice(List<dynamic> orders) {
    return orders.fold(0.0, (total, order) {
      return total + (order['price'] * order['quantity']);
    });
  }

  double calculateDiscountedPrice(double totalPrice, double discountPercentage) {
    double discountAmount = (totalPrice * discountPercentage) / 100;
    return totalPrice - discountAmount;
  }


  Future<void> updateIngredientQuantities(List<dynamic> orders) async {
    try {
      final Map<String, double> inventoryUpdates = {};

      for (var order in orders) {
        if (order['ingredients'] != null) {
          for (var ingredient in order['ingredients']) {
            final String ingredientName = ingredient['ingredientName'];
            final double quantityUsed =
                (double.tryParse(ingredient['quantityUsed'].toString()) ?? 0.0) *
                    (double.tryParse(order['quantity'].toString()) ?? 0.0);

            if (inventoryUpdates.containsKey(ingredientName)) {
              inventoryUpdates[ingredientName] =
                  inventoryUpdates[ingredientName]! + quantityUsed;
            } else {
              inventoryUpdates[ingredientName] = quantityUsed;
            }
          }
        }
      }

      for (final entry in inventoryUpdates.entries) {
        final ingredientName = entry.key;
        final quantityUsed = entry.value;

        final querySnapshot = await FirebaseFirestore.instance
            .collection('tables')
            .doc(branchCode)
            .collection('Inventory')
            .where('ingredientName', isEqualTo: ingredientName)
            .get();

        for (var doc in querySnapshot.docs) {
          final currentQuantity =
              (doc.data()['quantity'] as num?)?.toDouble() ?? 0.0;
          final updatedQuantity = currentQuantity - quantityUsed;

          await doc.reference.update({'quantity': updatedQuantity});
        }
      }
    } catch (e) {
      print('Error updating ingredient quantities: $e');
    }
  }
  Future<void> handleSavePayment() async {
    final loc = AppLocalizations.of(context)!;

    if (selectedTable != null && paymentMethod.isNotEmpty && paymentStatus.isNotEmpty) {
      try {
        // 🔁 Convert localized strings to English before saving
        final englishPaymentMethod = {
          loc.cash: 'Cash',
          loc.card: 'Card',
          loc.upi: 'UPI',
          loc.due: 'Due',
        }[paymentMethod] ?? 'Cash';

        final englishPaymentStatus = {
          loc.settled: 'Settled',
          loc.due: 'Due',
        }[paymentStatus] ?? 'Settled';

        final tableRef = _db
            .collection('tables')
            .doc(branchCode)
            .collection('tables')
            .doc(selectedTable!['id']);

        List<dynamic> updatedOrders = selectedTable!['orders'];
        double totalPrice = calculateTotalPrice(updatedOrders);
        double discountedPrice = calculateDiscountedPrice(totalPrice, discountPercentage);

        String updatedOrderStatus = '';

        if (englishPaymentStatus == 'Settled') {
          updatedOrderStatus = 'Payment Successfully Settled';
          updatedOrders = [];
        } else if (englishPaymentStatus == 'Due' && responsibleName.isNotEmpty) {
          updatedOrderStatus = 'Payment Due Successfully by - $responsibleName';
          updatedOrders = [];
        } else {
          Fluttertoast.showToast(msg: loc.enterResponsibleName);
          return;
        }


        // 🔄 Clear table and set order status
        await tableRef.update({
          'orders': [],
          'orderStatus': updatedOrderStatus,
        });

        // ✅ Save payment with English values
        await tableRef.collection('orders').add({
          'orders': selectedTable!['orders'],
          'payment': {
            'total': totalPrice,
            'discountedTotal': discountedPrice,
            'discountPercentage': discountPercentage,
            'status': englishPaymentStatus, // English
            'method': englishPaymentMethod, // English
            'responsible': englishPaymentStatus == 'Due' ? responsibleName : null,
            'timestamp': DateTime.now(),
          },
          'orderStatus': updatedOrderStatus,
          'timestamp': DateTime.now(),
        });

        await updateIngredientQuantities(selectedTable!['orders']);

        Fluttertoast.showToast(msg: loc.paymentSaved);
        Navigator.pop(context); // Close modal
        fetchTables();
      } catch (e) {
        print("Error saving payment: $e");
        Fluttertoast.showToast(msg: loc.errorSavingPayment);
      }
    } else {
      Fluttertoast.showToast(msg: loc.selectPaymentMethodAndStatus);
    }
  }

  void openPaymentModal(Map<String, dynamic> table) {
    selectedTable = table;
    paymentMethod = '';
    paymentStatus = '';
    responsibleName = '';
    discountPercentage = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildPaymentModal(),
    );
  }

  Widget _buildPaymentModal() {
    final loc = AppLocalizations.of(context)!;
    final orders = selectedTable?['orders'] ?? [];
    final totalPrice = calculateTotalPrice(orders);
    final discountedPrice = calculateDiscountedPrice(totalPrice, discountPercentage);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: isDarkMode ? darkModeCardColor.withOpacity(0.92) : lightModeCardColor.withOpacity(0.92),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: StatefulBuilder(
                builder: (context, modalSetState) => ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      '${loc.payment} - ${loc.table} ${selectedTable?['tableNumber']}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDarkMode ? darkModeTextColor : lightModeTextColor),
                    ),
                    const SizedBox(height: 16),

                    if (orders.isNotEmpty)
                      ...orders.map((order) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: isDarkMode ? darkModeCardColor : lightModeCardColor, // Card color
                        child: ListTile(
                          title: Text(order['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? darkModeCardTextColor : lightModeCardTextColor)),
                          subtitle: Text('${loc.qty}: ${order['quantity']} x ₹${order['price']}', style: TextStyle(color: isDarkMode ? darkModeCardTextColor : lightModeCardTextColor)),
                          trailing: Text(
                            '₹${(order['quantity'] * order['price']).toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.w500, color: isDarkMode ? darkModeCardTextColor : lightModeCardTextColor),
                          ),
                        ),
                      )),
                    if (orders.isEmpty)
                      Center(child: Text(loc.noOrdersFound, style: TextStyle(color: isDarkMode ? darkModeCardTextColor : lightModeCardTextColor))),

                    const Divider(height: 32, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${loc.total}:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                        Text('₹${totalPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                      ],
                    ),
                    // const SizedBox(height: 4),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     Text('${loc.discounted}:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                    //     Text('₹${discountedPrice.toStringAsFixed(2)}',
                    //         style: TextStyle(fontSize: 16, color: Colors.green.shade700)), // Keep green for positive effect
                    //   ],
                    // ),
                    const SizedBox(height: 20),

                    // TextField(
                    //   keyboardType: TextInputType.number,
                    //   decoration: InputDecoration(
                    //     labelText: '${loc.discount} %',
                    //     prefixIcon: Icon(Icons.percent, color: isDarkMode ? darkModeIconColor : lightModeIconColor),
                    //     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    //     labelStyle: TextStyle(color: isDarkMode ? darkModeCardTextColor : lightModeCardTextColor),
                    //     enabledBorder: OutlineInputBorder(
                    //       borderSide: BorderSide(color: isDarkMode ? darkModeCardTextColor : Colors.grey.shade400),
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //     focusedBorder: OutlineInputBorder(
                    //       borderSide: BorderSide(color: isDarkMode ? fabColor : Colors.blue.shade700),
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //   ),
                    //   style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor),
                    //   onChanged: (val) {
                    //     modalSetState(() {
                    //       discountPercentage = double.tryParse(val) ?? 0.0;
                    //     });
                    //   },
                    // ),
                    // const SizedBox(height: 24),

                    Text('${loc.paymentMethod}:', style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [loc.cash, loc.card, loc.upi, loc.due].map((method) {
                        return ChoiceChip(
                          label: Text(method),
                          selected: paymentMethod == method,
                          selectedColor: filterChipSelectedColor,
                          backgroundColor: isDarkMode ? Colors.blueGrey.shade700.withOpacity(0.2) : Colors.blue.shade100.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: paymentMethod == method ? filterChipTextColor : (isDarkMode ? darkModeCardTextColor : lightModeCardTextColor),
                          ),
                          onSelected: (_) {
                            modalSetState(() => paymentMethod = method);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    Text('${loc.paymentStatus}:', style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [loc.settled, loc.due].map((status) {
                        return ChoiceChip(
                          label: Text(status),
                          selected: paymentStatus == status,
                          selectedColor: status == loc.settled ? Colors.green.shade700 : Colors.red.shade700,
                          backgroundColor: isDarkMode ? Colors.grey.shade700.withOpacity(0.2) : Colors.grey.shade200,
                          labelStyle: TextStyle(
                            color: paymentStatus == status ? filterChipTextColor : (isDarkMode ? darkModeCardTextColor : lightModeCardTextColor),
                          ),
                          onSelected: (_) {
                            modalSetState(() => paymentStatus = status);
                          },
                        );
                      }).toList(),
                    ),

                    if (paymentStatus == loc.due) ...[
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          labelText: loc.responsiblePerson,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          labelStyle: TextStyle(color: isDarkMode ? darkModeCardTextColor : lightModeCardTextColor),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: isDarkMode ? darkModeCardTextColor : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: isDarkMode ? fabColor : Colors.blue.shade700),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor),
                        onChanged: (val) => modalSetState(() => responsibleName = val),
                      ),
                    ],

                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: handleSavePayment,
                      icon: const Icon(Icons.save),
                      label: Text(loc.savePayment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: fabColor,
                        foregroundColor: filterChipTextColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size.fromHeight(50),
                        elevation: 4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: selectedTable != null ? () => printReceipt(context, selectedTable!) : null,
                      icon: const Icon(Icons.print),
                      label: Text(loc.printReceipt),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade800,
                        foregroundColor: filterChipTextColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size.fromHeight(48),
                        elevation: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: isDarkMode ? darkModeBackgroundColor : lightModeBackgroundColor,
      appBar: isLargeScreen
          ? null // No AppBar on large screens (web)
          : AppBar(
        backgroundColor: isDarkMode ? darkModeAppBarColor : lightModeAppBarColor,

        iconTheme: IconThemeData(color: isDarkMode ? darkModeIconColor : lightModeIconColor),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode, color: isDarkMode ? darkModeIconColor : lightModeIconColor),
            onPressed: () {
              setState(() {
                isDarkMode = !isDarkMode;
              });
            },
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 0), // Added top padding here
        child: StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('tables')
              .doc(branchCode)
              .collection('tables')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor)));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            final tables = docs.map((d) {
              final data = d.data()! as Map<String, dynamic>;
              return {
                'id': d.id,
                ...data,
                'orderStatus': data['orderStatus'] ?? 'Running Order',
              };
            }).toList();

            if (tables.isEmpty) {
              return Center(
                child: Text(
                  "No tables available.",
                  style: TextStyle(color: isDarkMode ? darkModeCardTextColor : lightModeCardTextColor),
                ),
              );
            }

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 900 ? 5 : (MediaQuery.of(context).size.width > 600 ? 4 : 2), // Adjusted for smaller cards
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85, // Adjusted to make cards "smaller" (taller/narrower)
              ),
              itemCount: tables.length,
              itemBuilder: (context, index) {
                final table = tables[index];
                final totalPrice = calculateTotalPrice(table['orders']);
                final hasOrders = (table['orders'] as List?)?.isNotEmpty ?? false;

                return Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? darkModeCardColor : lightModeCardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode ? Colors.black.withOpacity(0.5) : Colors.black12,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: hasOrders ? Colors.red : Colors.green, // Adjusted colors
                      width: 1,
                    ),

                  ),
                  child: InkWell( // Changed from Material to InkWell
                    borderRadius: BorderRadius.circular(16), // Apply borderRadius here as well for InkWell
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MenuPage(tableId: table['id']),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.table_restaurant, size: 20, color: isDarkMode ? darkModeIconColor : lightModeIconColor),
                          const SizedBox(height: 8),
                          Text(
                            ' ${table['tableNumber']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? darkModeCardTextColor : lightModeCardTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Spacer(),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => openPaymentModal(table),
                              style: ElevatedButton.styleFrom(
                                elevation: 3,
                                backgroundColor: fabColor,
                                foregroundColor: filterChipTextColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.payment, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pay ₹${totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
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
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            // Show a FAB on large screens (web) for theme toggle
            return FloatingActionButton(
              onPressed: () {
                setState(() {
                  isDarkMode = !isDarkMode;
                });
              },
              backgroundColor: fabColor,
              child: Icon(
                isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: filterChipTextColor,
              ),
              tooltip: 'Toggle Theme',
            );
          } else {
            return FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddTable()),
                );
              },
              backgroundColor: fabColor,
              child: const Icon(Icons.add),
            );
          }
        },
      ),
    );
  }
}