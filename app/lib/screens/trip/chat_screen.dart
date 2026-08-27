import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../models/poll.dart';
import '../../models/trip.dart';
import '../../theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.trip});

  final Trip trip;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = List<ChatMessage>.from(ChatMessage.sampleThread);
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(sender: 'You', text: text, time: 'Now', isSelf: true));
      _inputController.clear();
    });
    _scrollToBottom();
  }

  Future<void> _openPollComposer() async {
    final poll = await showModalBottomSheet<Poll>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _PollComposeSheet(),
    );
    if (poll == null || !mounted) return;
    setState(() {
      _messages.add(ChatMessage(sender: 'You', text: 'Poll: ${poll.question}', time: 'Now', isSelf: true, poll: poll));
    });
    _scrollToBottom();
  }

  void _vote(Poll poll, String option) {
    setState(() => poll.vote(option, 'You'));
  }

  String get _subtitle {
    final accepted = ['You', ...widget.trip.members.where((m) => m.status == MemberStatus.member).map((m) => m.name)];
    if (accepted.length == 1) return accepted.first;
    return '${accepted.sublist(0, accepted.length - 1).join(', ')} & ${accepted.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.trip.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            Text(_subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final message = _messages[i];
                  return _MessageBubble(
                    message: message,
                    onVote: message.poll == null ? null : (option) => _vote(message.poll!, option),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Material(
                    color: AppColors.accentTint,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _openPollComposer,
                      child: const SizedBox(
                        width: 38,
                        height: 38,
                        child: Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: AppColors.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _send,
                      child: const SizedBox(
                        width: 38,
                        height: 38,
                        child: Icon(Icons.arrow_upward_rounded, size: 18, color: Colors.white),
                      ),
                    ),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onVote});

  final ChatMessage message;
  final void Function(String option)? onVote;

  @override
  Widget build(BuildContext context) {
    final align = message.isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!message.isSelf)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                message.sender,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ),
          if (message.poll != null)
            _PollCard(poll: message.poll!, onVote: onVote!)
          else
            Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: message.isSelf ? AppColors.accent : AppColors.divider,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: message.isSelf ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(message.time, style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll, required this.onVote});

  final Poll poll;
  final void Function(String option) onVote;

  @override
  Widget build(BuildContext context) {
    final myVote = poll.optionVotedBy('You');
    final total = poll.totalVotes;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 15, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  poll.question,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final option in poll.options) ...[
            _PollOptionRow(
              option: option,
              votes: poll.votesByOption[option]!.length,
              total: total,
              selected: myVote == option,
              onTap: () => onVote(option),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            total == 0 ? 'No votes yet' : '$total vote${total == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PollOptionRow extends StatelessWidget {
  const _PollOptionRow({
    required this.option,
    required this.votes,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final String option;
  final int votes;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : votes / total;
    final percent = (fraction * 100).round();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: 1.5),
        ),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: fraction,
              child: Container(color: AppColors.accentTint),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 15,
                    color: selected ? AppColors.accent : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  if (total > 0)
                    Text('$percent%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollComposeSheet extends StatefulWidget {
  const _PollComposeSheet();

  @override
  State<_PollComposeSheet> createState() => _PollComposeSheetState();
}

class _PollComposeSheetState extends State<_PollComposeSheet> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [TextEditingController(), TextEditingController()];

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 6) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    setState(() => _optionControllers.removeAt(index).dispose());
  }

  void _create() {
    final question = _questionController.text.trim();
    final options = _optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (question.isEmpty || options.length < 2) return;
    Navigator.of(context).pop(Poll(question: question, options: options));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('New poll', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 18),
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(labelText: 'Question', hintText: 'What weekend works best?'),
            ),
            const SizedBox(height: 16),
            const Text('OPTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            for (final (i, controller) in _optionControllers.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(hintText: 'Option ${i + 1}', isDense: true),
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        onPressed: () => _removeOption(i),
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.only(left: 8),
                      ),
                  ],
                ),
              ),
            if (_optionControllers.length < 6)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add option'),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent, padding: EdgeInsets.zero),
              ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _create, child: const Text('Create poll')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
