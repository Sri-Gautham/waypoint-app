class ChatMessage {
  const ChatMessage({
    required this.sender,
    required this.text,
    required this.time,
    required this.isSelf,
  });

  final String sender;
  final String text;
  final String time;
  final bool isSelf;

  static const sampleThread = [
    ChatMessage(sender: 'Sam Park', text: 'Just booked the cabin, confirmation is in my email.', time: '10:14 AM', isSelf: false),
    ChatMessage(sender: 'Alex Kim', text: 'Nice! What time should we leave Saturday?', time: '10:16 AM', isSelf: false),
    ChatMessage(sender: 'You', text: "Let's aim for 7am to beat traffic.", time: '10:20 AM', isSelf: true),
    ChatMessage(sender: 'Sam Park', text: 'Works for me.', time: '10:21 AM', isSelf: false),
  ];
}
