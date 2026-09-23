import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final messages = <({String text, bool mine})>[
    (text: 'สวัสดีค่ะ ยินดีช่วยแนะนำที่พักให้คุณ', mine: false),
    (text: 'ช่วยแนะนำที่พักริมทะเลให้หน่อย', mine: true),
    (text: 'แนะนำ Blue Coast Resort คะแนน 4.9 เหมาะสำหรับวันพักผ่อนค่ะ', mine: false),
  ];

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void send() {
    final text = input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add((text: text, mine: true));
      messages.add((text: 'รับข้อความแล้วค่ะ นี่เป็นการตอบกลับตัวอย่างของ Frontend Demo', mine: false));
      input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teenon Assistant')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.07), borderRadius: BorderRadius.circular(20)),
              child: const Row(
                children: [
                  GradientIconBox(icon: Icons.support_agent_rounded),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ผู้ช่วยจองที่พัก', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.text)),
                        SizedBox(height: 2),
                        Text('ตอบกลับตัวอย่าง • Frontend only', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return Align(
                    alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      decoration: BoxDecoration(
                        color: message.mine ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(message.mine ? 18 : 5),
                          bottomRight: Radius.circular(message.mine ? 5 : 18),
                        ),
                        border: message.mine ? null : Border.all(color: AppColors.border),
                      ),
                      child: Text(message.text, style: TextStyle(color: message.mine ? Colors.white : AppColors.text, height: 1.35)),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(hintText: 'พิมพ์ข้อความ...', prefixIcon: Icon(Icons.chat_bubble_outline_rounded)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(onPressed: send, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
