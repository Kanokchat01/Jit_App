import 'package:flutter/material.dart';

class ConsentEmotionCameraPage extends StatelessWidget {
  const ConsentEmotionCameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ขออนุญาตใช้งานกล้อง')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เพื่อเพิ่มความแม่นยำในการประเมิน ระบบจะวิเคราะห์อารมณ์จากใบหน้าในระหว่างทำแบบประเมินเชิงลึก',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('• ไม่บันทึกรูปหรือวิดีโอ'),
            const Text('• ประมวลผลบนเครื่องของผู้ใช้ (On-device)'),
            const Text('• เก็บเฉพาะผลสรุปอารมณ์เป็นคะแนน/สถิติ'),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('ไม่ยินยอม'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('ยินยอม'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}