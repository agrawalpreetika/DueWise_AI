import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_service.dart';
import 'subscription_query_service.dart';
import 'features/subscriptions/subscription_model.dart';
import 'features/subscriptions/subscription_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final AiService _aiService = AiService();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Map<String, String>> _buildHistoryPayload() {
    final recent = _messages.length > 8
        ? _messages.sublist(_messages.length - 8)
        : _messages;

    return recent
        .map(
          (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
        )
        .toList();
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    final historyPayload = _buildHistoryPayload();
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    final result = await _aiService.sendMessageToAgent(
      text,
      history: historyPayload,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result != null) {
        if (result['type'] == 'tool_call') {
          final functionName = result['function']?.toString() ?? '';
          final toolData =
              (result['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};

          try {
            if (functionName == 'add_subscription') {
              final title = toolData['title']?.toString() ?? 'Unknown';
              final amount = (toolData['amount'] as num).toDouble();
              final billingCycle = (toolData['billingCycle'] ?? 'MONTHLY')
                  .toString()
                  .toUpperCase();
              final startDateStr =
                  toolData['startDate']?.toString() ??
                  DateTime.now().toIso8601String().split('T')[0];
              final category = toolData['category']?.toString() ?? 'Other';

              int? customIntervalDays;
              if (billingCycle == 'CUSTOM' &&
                  toolData['customIntervalDays'] != null) {
                customIntervalDays = (toolData['customIntervalDays'] as num)
                    .toInt();
              }

              DateTime parsedStartDate =
                  DateTime.tryParse(startDateStr) ?? DateTime.now();

              DateTime calculatedDueDate = Subscription.calculateNextDueDate(
                parsedStartDate,
                billingCycle,
                intervalDays: customIntervalDays,
              );

              final newSubscription = Subscription(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                category: category,
                amount: amount,
                currency: 'INR',
                entryType: 'subscription',
                billingCycle: billingCycle,
                customIntervalDays: customIntervalDays,
                startDate: parsedStartDate,
                nextDueDate: calculatedDueDate,
                isFreeTrial: false,
                trialEndDate: null,
                isPaused: false,
                isPaid: false,
              );

              ref
                  .read(subscriptionProvider.notifier)
                  .addSubscription(newSubscription);

              _messages.add(
                ChatMessage(
                  text:
                      "✅ Successfully added '$title' ($category) of ₹$amount ($billingCycle${customIntervalDays != null ? ' - every $customIntervalDays days' : ''})! Next due: ${calculatedDueDate.toIso8601String().split('T')[0]}",
                  isUser: false,
                ),
              );
            } else if (functionName == 'add_one_time_bill') {
              final title = toolData['title']?.toString() ?? 'One-Time Bill';
              final amount = (toolData['amount'] as num).toDouble();
              final dueDateStr =
                  toolData['dueDate']?.toString() ??
                  DateTime.now().toIso8601String().split('T')[0];
              final category = toolData['category']?.toString() ?? 'Utilities';

              final parsedDueDate =
                  DateTime.tryParse(dueDateStr) ?? DateTime.now();

              final newBill = Subscription(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                category: category,
                amount: amount,
                currency: 'INR',
                entryType: 'one_time_bill',
                billingCycle: null,
                customIntervalDays: null,
                startDate: null,
                nextDueDate: parsedDueDate,
                isFreeTrial: false,
                trialEndDate: null,
                isPaused: false,
                isPaid: false,
              );

              ref.read(subscriptionProvider.notifier).addSubscription(newBill);

              _messages.add(
                ChatMessage(
                  text:
                      "✅ Added one-time bill '$title' ($category) of ₹$amount! Pay by: ${parsedDueDate.toIso8601String().split('T')[0]}",
                  isUser: false,
                ),
              );
            } else if (functionName == 'query_subscriptions') {
              final currentSubscriptions = ref.read(subscriptionProvider);
              final queryReply = SubscriptionQueryService.executeQuery(
                subscriptions: currentSubscriptions,
                queryData: toolData,
              );

              _messages.add(ChatMessage(text: queryReply, isUser: false));
            } else {
              _messages.add(
                ChatMessage(
                  text: result['response']?.toString() ?? "Action completed.",
                  isUser: false,
                ),
              );
            }
          } catch (e) {
            _messages.add(
              ChatMessage(text: "⚠️ Parsing error: $e", isUser: false),
            );
          }
        } else {
          _messages.add(
            ChatMessage(
              text: result['response'] ?? "I'm here to help!",
              isUser: false,
            ),
          );
        }
      } else {
        _messages.add(
          ChatMessage(
            text: "Sorry, could not connect to the backend server. Please make sure the backend server is reachable.",
            isUser: false,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('DueWise AI Assistant'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        "Hello! I am your DueWise AI Assistant.\nYou can say things like:\n\n'Add Netflix subscription of 650 monthly'\n'Add electricity bill of 1200 due on 28th'\n'What subscriptions are due today?'",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(12.0),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: message.isUser
                                ? Colors.deepPurple
                                : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            message.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: Colors.deepPurple),
            ),
          Container(
            color: const Color(0xFF1E1E1E),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: _handleSubmitted,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText:
                              'Type a message (e.g., What is due today?)...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.deepPurple),
                      onPressed: () => _handleSubmitted(_controller.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
