import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import 'subscription_model.dart';
import 'subscription_provider.dart';

class AddSubscriptionScreen extends ConsumerStatefulWidget {
  const AddSubscriptionScreen({super.key});

  @override
  ConsumerState<AddSubscriptionScreen> createState() =>
      _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends ConsumerState<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _customValueController = TextEditingController();
  final _trialDaysController = TextEditingController(
    text: '7',
  ); // Default 7 days trial

  String _selectedCategory = 'Entertainment';
  String _selectedBillingCycle = 'MONTHLY';
  String _postTrialBillingCycle = 'MONTHLY'; // Billing cycle after trial ends

  DateTime _startDate = DateTime.now();
  DateTime _nextDueDate = DateTime.now().add(const Duration(days: 30));
  DateTime? _trialEndDate;

  String _customUnit = 'Days'; // 'Days' or 'Months'
  bool _isFreeTrial = false;

  final List<String> _categories = [
    'Entertainment',
    'Utilities',
    'Software',
    'Gym',
    'Insurance',
    'Education',
    'Other',
  ];

  final List<String> _billingCycles = ['MONTHLY', 'YEARLY', 'CUSTOM'];

  // Preset Template Data
  final _presetTemplates = [
    {'title': 'Netflix', 'amount': '649', 'category': 'Entertainment'},
    {'title': 'Spotify', 'amount': '119', 'category': 'Entertainment'},
    {'title': 'Gym Membership', 'amount': '1500', 'category': 'Gym'},
    {'title': 'Mobile Bill', 'amount': '499', 'category': 'Utilities'},
    {'title': 'Internet Broadband', 'amount': '999', 'category': 'Utilities'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _customValueController.dispose();
    _trialDaysController.dispose();
    super.dispose();
  }

  void _applyPreset(Map<String, String> preset) {
    setState(() {
      _titleController.text = preset['title']!;
      _amountController.text = preset['amount']!;
      _selectedCategory = preset['category']!;
    });
  }

  // Auto-calculate Next Due Date & Trial End Date based on selections
  void _updateCalculatedDueDate() {
    setState(() {
      if (_isFreeTrial) {
        // 1. Calculate Trial End Date from Start Date + Trial Days
        final trialDays = int.tryParse(_trialDaysController.text.trim()) ?? 7;
        _trialEndDate = _startDate.add(Duration(days: trialDays));

        // 2. First billing / next due date becomes the trial end date,
        // using the post-trial billing cycle for subsequent cycles.
        int? customDays;
        if (_postTrialBillingCycle == 'CUSTOM') {
          final val = int.tryParse(_customValueController.text.trim()) ?? 30;
          customDays = _customUnit == 'Months' ? val * 30 : val;
        }

        _nextDueDate = _trialEndDate!;
      } else {
        _trialEndDate = null;
        int? customDays;
        if (_selectedBillingCycle == 'CUSTOM') {
          final val = int.tryParse(_customValueController.text.trim()) ?? 0;
          customDays = _customUnit == 'Months' ? val * 30 : val;
        }

        _nextDueDate = Subscription.calculateNextDueDate(
          _startDate,
          _selectedBillingCycle,
          intervalDays: customDays,
        );
      }
    });
  }

  void _presentStartDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (pickedDate != null) {
      setState(() {
        _startDate = pickedDate;
        _updateCalculatedDueDate();
      });
    }
  }

  void _saveSubscription() {
    if (_formKey.currentState!.validate()) {
      int? customDays;
      final activeCycle = _isFreeTrial
          ? _postTrialBillingCycle
          : _selectedBillingCycle;

      if (activeCycle == 'CUSTOM') {
        final val = int.tryParse(_customValueController.text.trim()) ?? 30;
        customDays = _customUnit == 'Months' ? val * 30 : val;
      }

      final newSubscription = Subscription(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        category: _selectedCategory,
        amount: double.parse(_amountController.text.trim()),
        billingCycle: activeCycle,
        customIntervalDays: customDays,
        startDate: _startDate,
        nextDueDate: _nextDueDate,
        isFreeTrial: _isFreeTrial,
        trialEndDate: _trialEndDate,
      );

      ref.read(subscriptionProvider.notifier).addSubscription(newSubscription);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Add Subscription')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 1. Quick Presets Section
              const Text(
                'Quick Presets',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presetTemplates.length,
                  itemBuilder: (context, index) {
                    final preset = _presetTemplates[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        avatar: const Icon(Icons.flash_on, size: 16),
                        label: Text(preset['title']!),
                        onPressed: () => _applyPreset(preset),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 2. Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Subscription Title (e.g., Netflix)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 16),

              // 3. Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      double.tryParse(value.trim()) == null ||
                      double.parse(value.trim()) <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 4. Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 16),

              // 5. Start Date Selector
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                title: Text('Start Date: ${dateFormat.format(_startDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _presentStartDatePicker,
              ),
              const SizedBox(height: 16),

              // 6. Free Trial Switch
              SwitchListTile(
                title: const Text('Is this a Free Trial?'),
                subtitle: const Text(
                  'Enable to track trial duration & conversion',
                ),
                value: _isFreeTrial,
                onChanged: (value) {
                  setState(() {
                    _isFreeTrial = value;
                    _updateCalculatedDueDate();
                  });
                },
              ),
              const SizedBox(height: 16),

              // 7. Free Trial Specific Dynamic Fields
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
                      TextFormField(
                        controller: _trialDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Trial Duration (in Days)',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (_) => _updateCalculatedDueDate(),
                        validator: (value) {
                          if (_isFreeTrial &&
                              (value == null ||
                                  int.tryParse(value.trim()) == null ||
                                  int.parse(value.trim()) <= 0)) {
                            return 'Enter valid trial days';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _postTrialBillingCycle,
                        decoration: const InputDecoration(
                          labelText: 'Post-Trial Billing Cycle',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _billingCycles.map((cycle) {
                          return DropdownMenuItem(
                            value: cycle,
                            child: Text(cycle),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _postTrialBillingCycle = value;
                              _updateCalculatedDueDate();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 8. Standard Billing Cycle Dropdown (Hidden or replaced if Free Trial is active)
              if (!_isFreeTrial) ...[
                DropdownButtonFormField<String>(
                  value: _selectedBillingCycle,
                  decoration: const InputDecoration(
                    labelText: 'Billing Cycle',
                    border: OutlineInputBorder(),
                  ),
                  items: _billingCycles.map((cycle) {
                    return DropdownMenuItem(value: cycle, child: Text(cycle));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedBillingCycle = value;
                        _updateCalculatedDueDate();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],

              // 9. Custom Interval Options (Appears when CUSTOM is selected in either mode)
              if ((!_isFreeTrial && _selectedBillingCycle == 'CUSTOM') ||
                  (_isFreeTrial && _postTrialBillingCycle == 'CUSTOM')) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _customValueController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          // ✅ Fixed label: Shows 'Post-Trial Duration Value' if free trial, else 'Repeat Interval Value'
                          labelText: _isFreeTrial
                              ? 'Post-Trial Duration Value'
                              : 'Repeat Interval Value',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => _updateCalculatedDueDate(),
                        validator: (value) {
                          if ((!_isFreeTrial &&
                                      _selectedBillingCycle == 'CUSTOM' ||
                                  _isFreeTrial &&
                                      _postTrialBillingCycle == 'CUSTOM') &&
                              (value == null ||
                                  int.tryParse(value.trim()) == null ||
                                  int.parse(value.trim()) <= 0)) {
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
                              _updateCalculatedDueDate();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 10. Auto-Calculated Next Due / Trial End Date Display
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
                              ? 'Trial Ends / First Bill Date:'
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
                          dateFormat.format(_nextDueDate),
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

              // 11. Submit Button
              ElevatedButton(
                onPressed: _saveSubscription,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Save Subscription',
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
