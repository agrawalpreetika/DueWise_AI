import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'subscription_model.dart';
import 'subscription_provider.dart';

class EditSubscriptionScreen extends ConsumerStatefulWidget {
  final Subscription subscription;

  const EditSubscriptionScreen({super.key, required this.subscription});

  @override
  ConsumerState<EditSubscriptionScreen> createState() =>
      _EditSubscriptionScreenState();
}

class _EditSubscriptionScreenState
    extends ConsumerState<EditSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _customIntervalController;

  late bool _isOneTimeBill;
  late String _category;
  late String _billingCycle;
  late DateTime _startDate;
  late DateTime _nextDueDate;
  late bool _isFreeTrial;
  DateTime? _trialEndDate;

  String _customUnit = 'Days';
  int _customIntervalValue = 30;

  final List<String> _categories = [
    'Entertainment',
    'Utilities',
    'Software',
    'Gym',
    'Insurance',
    'Education',
    'Other',
  ];

  final List<String> _billingCycles = ['Monthly', 'Yearly', 'Custom'];

  @override
  void initState() {
    super.initState();
    final sub = widget.subscription;
    _isOneTimeBill = sub.isOneTimeBill;
    _titleController = TextEditingController(text: sub.title);
    _amountController = TextEditingController(text: sub.amount.toString());

    if (sub.customIntervalDays != null &&
        sub.customIntervalDays! > 0 &&
        sub.customIntervalDays! % 30 == 0) {
      _customIntervalValue = sub.customIntervalDays! ~/ 30;
      _customUnit = 'Months';
    } else {
      _customIntervalValue = sub.customIntervalDays ?? 30;
      _customUnit = 'Days';
    }

    _customIntervalController = TextEditingController(
      text: _customIntervalValue.toString(),
    );

    _category = sub.category;
    _billingCycle = _normalizeBillingCycle(sub.billingCycle);

    _startDate = sub.startDate ?? DateTime.now();
    _nextDueDate = sub.nextDueDate;
    _isFreeTrial = _isOneTimeBill ? false : sub.isFreeTrial;
    _trialEndDate = _isOneTimeBill ? null : sub.trialEndDate;

    if (!_categories.contains(_category)) {
      _category = _categories.firstWhere(
        (c) => c.toLowerCase() == sub.category.toLowerCase(),
        orElse: () => _isOneTimeBill ? 'Utilities' : 'Other',
      );
    }
  }

  String _normalizeBillingCycle(String? cycle) {
    final upper = (cycle ?? 'MONTHLY').toUpperCase();
    if (upper == 'MONTHLY') return 'Monthly';
    if (upper == 'YEARLY') return 'Yearly';
    if (upper == 'CUSTOM') return 'Custom';
    return 'Monthly';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _customIntervalController.dispose();
    super.dispose();
  }

  void _updateCalculatedDates() {
    if (_isOneTimeBill) return;

    setState(() {
      if (_isFreeTrial) {
        _trialEndDate ??= _startDate.add(const Duration(days: 7));
        _nextDueDate = _trialEndDate!;
      } else {
        int? customDays;
        if (_billingCycle == 'Custom') {
          final val = int.tryParse(_customIntervalController.text.trim()) ?? 30;
          customDays = _customUnit == 'Months' ? val * 30 : val;
        }

        final modelCycle = _billingCycle.toUpperCase();
        _nextDueDate = Subscription.calculateNextDueDate(
          _startDate,
          modelCycle,
          intervalDays: customDays,
        );
        _trialEndDate = null;
      }
    });
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _nextDueDate = picked;
      });
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _updateCalculatedDates();
      });
    }
  }

  Future<void> _selectTrialEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _trialEndDate ?? _startDate.add(const Duration(days: 7)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _trialEndDate = picked;
        _nextDueDate = picked;
      });
    }
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      if (_isOneTimeBill) {
        final updatedBill = Subscription(
          id: widget.subscription.id,
          title: _titleController.text.trim(),
          amount: double.parse(_amountController.text.trim()),
          currency: widget.subscription.currency,
          category: _category,
          entryType: 'one_time_bill',
          billingCycle: null,
          customIntervalDays: null,
          startDate: null,
          nextDueDate: _nextDueDate,
          isFreeTrial: false,
          trialEndDate: null,
          isPaused: widget.subscription.isPaused,
          isPaid: widget.subscription.isPaid,
        );

        ref.read(subscriptionProvider.notifier).updateSubscription(updatedBill);
        Navigator.of(context).pop();
        return;
      }

      int? customDays;
      if (_billingCycle == 'Custom') {
        final val = int.tryParse(_customIntervalController.text.trim()) ?? 30;
        customDays = _customUnit == 'Months' ? val * 30 : val;
      }

      final updatedSub = Subscription(
        id: widget.subscription.id,
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        currency: widget.subscription.currency,
        category: _category,
        entryType: 'subscription',
        billingCycle: _billingCycle.toUpperCase(),
        startDate: _startDate,
        nextDueDate: _nextDueDate,
        customIntervalDays: customDays,
        isFreeTrial: _isFreeTrial,
        trialEndDate: _isFreeTrial ? _trialEndDate : null,
        isPaused: widget.subscription.isPaused,
        isPaid: false,
      );

      ref.read(subscriptionProvider.notifier).updateSubscription(updatedSub);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isOneTimeBill ? 'Edit One-Time Bill' : 'Edit Subscription',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: _isOneTimeBill
                      ? 'Bill Title'
                      : 'Subscription Title',
                  border: const OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Please enter an amount'
                    : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _category = val!),
              ),
              const SizedBox(height: 16),

              if (_isOneTimeBill) ...[
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  title: const Text('Due Date (Pay By)'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(_nextDueDate)),
                  trailing: const Icon(Icons.event),
                  onTap: () => _selectDueDate(context),
                ),
                const SizedBox(height: 24),
              ] else ...[
                // Start Date Picker
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  title: const Text('Start Date'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectStartDate(context),
                ),
                const SizedBox(height: 16),

                // Free Trial Switch
                SwitchListTile(
                  title: const Text('Is Free Trial?'),
                  subtitle: const Text('Enable special trial tracking'),
                  value: _isFreeTrial,
                  onChanged: (val) {
                    setState(() {
                      _isFreeTrial = val;
                      _updateCalculatedDates();
                    });
                  },
                ),
                const SizedBox(height: 16),

                if (_isFreeTrial) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Free Trial Configuration',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(color: Colors.orange.shade200),
                          ),
                          title: const Text('Trial End Date'),
                          subtitle: Text(
                            _trialEndDate != null
                                ? DateFormat('yyyy-MM-dd')
                                      .format(_trialEndDate!)
                                : 'Select Trial End Date',
                          ),
                          trailing: const Icon(
                            Icons.event_available,
                            color: Colors.orange,
                          ),
                          onTap: () => _selectTrialEndDate(context),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _billingCycle,
                          decoration: const InputDecoration(
                            labelText: 'Post-Trial Billing Cycle',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _billingCycles
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _billingCycle = val;
                                _updateCalculatedDates();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (!_isFreeTrial) ...[
                  DropdownButtonFormField<String>(
                    value: _billingCycle,
                    decoration: const InputDecoration(
                      labelText: 'Billing Cycle',
                      border: OutlineInputBorder(),
                    ),
                    items: _billingCycles
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _billingCycle = val;
                          _updateCalculatedDates();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                if (_billingCycle == 'Custom') ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _customIntervalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Interval Value',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => _updateCalculatedDates(),
                          validator: (val) {
                            if (_billingCycle == 'Custom' &&
                                (val == null ||
                                    int.tryParse(val.trim()) == null ||
                                    int.parse(val.trim()) <= 0)) {
                              return 'Enter valid value';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _customUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                          items: ['Days', 'Months'].map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _customUnit = val;
                                _updateCalculatedDates();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isFreeTrial
                        ? Colors.orange.shade50
                        : Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isFreeTrial
                          ? Colors.orange.shade200
                          : Colors.deepPurple.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isFreeTrial
                                ? 'First Billing Date (Post-Trial):'
                                : 'Next Due Date (Auto-calculated):',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isFreeTrial
                                  ? Colors.orange.shade800
                                  : Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy-MM-dd').format(_nextDueDate),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isFreeTrial
                                  ? Colors.orange.shade900
                                  : Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.auto_awesome,
                        color: _isFreeTrial
                            ? Colors.orange.shade800
                            : Colors.deepPurple,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
