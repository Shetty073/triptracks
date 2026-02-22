import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/trip.dart';
import 'package:frontend/features/trip_details/providers/trip_interactions_provider.dart';
import 'package:intl/intl.dart';

class ExpensesTab extends ConsumerStatefulWidget {
  final Trip trip;
  const ExpensesTab({super.key, required this.trip});

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _showAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (e.g. Gas, Lunch)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_descController.text.isNotEmpty &&
                  _amountController.text.isNotEmpty) {
                try {
                  await ref
                      .read(tripInteractionsProvider)
                      .addExpense(
                        widget.trip.id,
                        _descController.text,
                        double.parse(_amountController.text),
                      );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _descController.clear();
                  _amountController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Expense Added')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalExpenses = widget.trip.expenses.fold(
      0,
      (sum, item) => sum + item.amount,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: \$${totalExpenses.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
                onPressed: _showAddExpenseDialog,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: widget.trip.expenses.isEmpty
              ? const Center(child: Text('No expenses recorded yet.'))
              : ListView.builder(
                  itemCount: widget.trip.expenses.length,
                  itemBuilder: (context, index) {
                    final expense = widget.trip.expenses[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child: Icon(Icons.receipt, color: Colors.white),
                      ),
                      title: Text(expense.description),
                      subtitle: Text(
                        'Paid by: ${expense.paidBy} on ${DateFormat.yMd().format(expense.date)}',
                      ),
                      trailing: Text(
                        '\$${expense.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
