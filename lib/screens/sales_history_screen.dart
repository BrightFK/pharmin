// // lib/screens/sales_history_screen.dart
// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:intl/intl.dart';
//
// import '../models/medicine.dart';
// import '../models/transaction.dart';
// import '../providers/hive_provider.dart';
// import '../widgets/glass_card.dart';
//
// class SalesHistoryScreen extends StatelessWidget {
//   const SalesHistoryScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final transactionBox = Hive.box<Transaction>(HiveProvider.transactionsBox);
//     final transactions =
//         transactionBox.values.where((t) => t.type == 'sale').toList()
//           ..sort((a, b) => b.date.compareTo(a.date));
//
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         title: const Text(
//           'Sales History',
//           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//         ),
//         centerTitle: true,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [
//               const Color(0xFF0D1B2A),
//               const Color(0xFF1B263B),
//               const Color(0xFF2C3E50),
//             ],
//           ),
//         ),
//         child: SafeArea(
//           child: transactions.isEmpty
//               ? const Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.receipt_long, color: Colors.white38, size: 60),
//                       SizedBox(height: 16),
//                       Text(
//                         'No sales yet',
//                         style: TextStyle(color: Colors.white60, fontSize: 16),
//                       ),
//                       SizedBox(height: 8),
//                       Text(
//                         'Sales will appear here',
//                         style: TextStyle(color: Colors.white38, fontSize: 12),
//                       ),
//                     ],
//                   ),
//                 )
//               : ListView.builder(
//                   padding: const EdgeInsets.all(16),
//                   itemCount: transactions.length,
//                   itemBuilder: (context, index) {
//                     final transaction = transactions[index];
//                     return Padding(
//                       padding: const EdgeInsets.only(bottom: 8),
//                       child: GlassCard(
//                         child: ListTile(
//                           leading: CircleAvatar(
//                             backgroundColor: Colors.green.withValues(
//                               alpha: 0.2,
//                             ),
//                             child: const Icon(
//                               Icons.receipt,
//                               color: Colors.greenAccent,
//                             ),
//                           ),
//                           title: Text(
//                             DateFormat('MMM d, yyyy').format(transaction.date),
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           subtitle: Text(
//                             '${transaction.items.length} items • ${transaction.paymentMethod ?? 'Cash'}',
//                             style: const TextStyle(color: Colors.white60),
//                           ),
//                           trailing: Text(
//                             '\$${transaction.totalAmount.toStringAsFixed(2)}',
//                             style: const TextStyle(
//                               color: Colors.greenAccent,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                           onTap: () {
//                             // Show receipt dialog
//                             _showReceiptDialog(context, transaction);
//                           },
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//         ),
//       ),
//     );
//   }
//
//   void _showReceiptDialog(BuildContext context, Transaction transaction) {
//     final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: const Color(0xFF1A237E),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Text('🧾 Receipt', style: TextStyle(color: Colors.white)),
//         content: Container(
//           constraints: const BoxConstraints(maxWidth: 400),
//           child: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Divider(color: Colors.white24),
//                 ...transaction.items.map((item) {
//                   final med = medBox.get(item.medicineId);
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 4),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Expanded(
//                           child: Text(
//                             '${med?.name ?? 'Unknown'} x ${item.quantity.toStringAsFixed(2)}',
//                             style: const TextStyle(color: Colors.white70),
//                           ),
//                         ),
//                         Text(
//                           '\$${item.lineTotal.toStringAsFixed(2)}',
//                           style: const TextStyle(color: Colors.white),
//                         ),
//                       ],
//                     ),
//                   );
//                 }),
//                 const Divider(color: Colors.white24),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text(
//                       'Total',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                     Text(
//                       '\$${transaction.totalAmount.toStringAsFixed(2)}',
//                       style: const TextStyle(
//                         color: Colors.greenAccent,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   'Payment: ${transaction.paymentMethod ?? 'Cash'}',
//                   style: const TextStyle(color: Colors.white60),
//                 ),
//                 if (transaction.notes != null) ...[
//                   const SizedBox(height: 4),
//                   Text(
//                     'Notes: ${transaction.notes}',
//                     style: const TextStyle(color: Colors.white38),
//                   ),
//                 ],
//                 const SizedBox(height: 8),
//                 Text(
//                   DateFormat('MMM d, yyyy - h:mm a').format(transaction.date),
//                   style: const TextStyle(color: Colors.white38),
//                 ),
//               ],
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close', style: TextStyle(color: Colors.white60)),
//           ),
//         ],
//       ),
//     );
//   }
// }
