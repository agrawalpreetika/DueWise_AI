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

  bool _isOneTimeBill = false; // false = Subscription, true = One-Time Bill
  String _selectedCategory = 'Entertainment';
  String _selectedBillingCycle = 'MONTHLY';
  String _postTrialBillingCycle = 'MONTHLY'; // Billing cycle after trial ends

  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
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

  // Preset Template Data for Recurring Subscriptions
  final _subscriptionPresets = [
    {'title': 'Netflix', 'amount': '649', 'category': 'Entertainment'},
    {'title': 'Spotify', 'amount': '119', 'category': 'Entertainment'},
    {'title': 'Gym Membership', 'amount': '1500', 'category': 'Gym'},
    {'title': 'Mobile Bill', 'amount': '499', 'category': 'Utilities'},
    {'title': 'Internet Broadband', 'amount': '999', 'category': 'Utilities'},
  ];

  // Preset Template Data for One-Time Bills
  final _oneTimeBillPresets = [
    {'title': 'Electricity Bill', 'amount': '1250', 'category': 'Utilities'},
    {'title': 'Water Bill', 'amount': '350', 'category': 'Utilities'},
    {'title': 'Gas Cylinder / Bill', 'amount': '900', 'category': 'Utilities'},
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

  // Auto-calculate Next Due Date & Trial End Date for recurring subscriptions
  void _updateCalculatedDueDate() {
    if (_isOneTimeBill) return;

    setState(() {
      if (_isFreeTrial) {
        final trialDays = int.tryParse(_trialDaysController.text.trim()) ?? 7;
        _trialEndDate = _startDate.add(Duration(days: trialDays));
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

  void _presentDueDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (pickedDate != null) {
      setState(() {
        _dueDate = pickedDate;
      });
    }
  }

  void _saveSubscription() {
    if (_formKey.currentState!.validate()) {
      if (_isOneTimeBill) {
        final newBill = Subscription(
          id: const Uuid().v4(),
          title: _titleController.text.trim(),
          category: _selectedCategory,
          amount: double.parse(_amountController.text.trim()),
          currency: 'INR',
          entryType: 'one_time_bill',
          billingCycle: null,
          customIntervalDays: null,
          startDate: null,
          nextDueDate: _dueDate,
          isFreeTrial: false,
          trialEndDate: null,
          isPaid: false,
        );

        ref.read(subscriptionProvider.notifier).addSubscription(newBill);
        Navigator.of(context).pop();
        return;
      }

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
        currency: 'INR',
        entryType: 'subscription',
        billingCycle: activeCycle,
        customIntervalDays: customDays,
        startDate: _startDate,
        nextDueDate: _nextDueDate,
        isFreeTrial: _isFreeTrial,
        trialEndDate: _trialEndDate,
        isPaid: false,
      );

      ref.read(subscriptionProvider.notifier).addSubscription(newSubscription);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final activePresets = _isOneTimeBill
        ? _oneTimeBillPresets
        : _subscriptionPresets;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isOneTimeBill ? 'Add One-Time Bill' : 'Add Subscription'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 0. Subscription vs One-Time Bill Toggle
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Subscription'),
                    icon: Icon(Icons.autorenew),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('One-Time Bill'),
                    icon: Icon(Icons.receipt_long),
                  ),
                ],
                selected: {_isOneTimeBill},
                onSelectionChanged: (Set<bool> selection) {
                  final nextIsOneTime = selection.first;
                  setState(() {
                    _isOneTimeBill = nextIsOneTime;
                    if (_isOneTimeBill) {
                      _isFreeTrial = false;
                      _trialEndDate = null;
                      if (_selectedCategory == 'Entertainment') {
                        _selectedCategory = 'Utilities';
                      }
                    } else {
                      _updateCalculatedDueDate();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

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
                  itemCount: activePresets.length,
                  itemBuilder: (context, index) {
                    final preset = activePresets[index];
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
                decoration: InputDecoration(
                  labelText: _isOneTimeBill
                      ? 'Bill Title (e.g., Electricity Bill)'
                      : 'Subscription Title (e.g., Netflix)',
                  border: const OutlineInputBorder(),
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

              if (_isOneTimeBill) ...[
                // One-Time Bill: Due Date ("Pay by" date) only; no startDate or billingCycle
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  title: Text(
                    'Due Date (Pay By): ${dateFormat.format(_dueDate)}',
                  ),
                  subtitle: const Text('One-time payment — no recurring cycle'),
                  trailing: const Icon(Icons.event),
                  onTap: _presentDueDatePicker,
                ),
                const SizedBox(height: 24),
              ] else ...[
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

                // 8. Standard Billing Cycle Dropdown
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

                // 9. Custom Interval Options
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
              ],

              // 11. Submit Button
              ElevatedButton(
                onPressed: _saveSubscription,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _isOneTimeBill ? 'Save One-Time Bill' : 'Save Subscription',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
