import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminNewsScreen extends StatelessWidget {
  const AdminNewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pink = Colors.pink.shade300;

    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(title: const Text("จัดการข่าวสาร"), backgroundColor: pink),
      floatingActionButton: FloatingActionButton(
        backgroundColor: pink,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateNewsScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('news')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("ยังไม่มีข่าว"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              DateTime? createdAt;
              if (data['createdAt'] is Timestamp) {
                createdAt = (data['createdAt'] as Timestamp).toDate();
              }

              final formattedDate = createdAt != null
                  ? DateFormat('dd MMM yyyy • HH:mm').format(createdAt)
                  : '';

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const SizedBox(height: 10),

                      Text(
                        data['content'] ?? '',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),

                      const SizedBox(height: 14),

                      // 🔥 เวลา + ปุ่มล่างโพสต์ (อยู่บรรทัดเดียวกัน)
                      Row(
                        children: [
                          // 🕒 เวลาโพสต์ (ชิดซ้าย)
                          if (formattedDate.isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),

                          const Spacer(),

                          // ✏️ Edit
                          TextButton.icon(
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text("Edit"),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditNewsScreen(
                                    docId: doc.id,
                                    oldTitle: data['title'] ?? '',
                                    oldContent: data['content'] ?? '',
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(width: 8),

                          // 🗑 Delete
                          TextButton.icon(
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text("Delete"),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("ลบโพสต์"),
                                  content: const Text(
                                    "คุณแน่ใจหรือไม่ว่าต้องการลบโพสต์นี้",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text("ยกเลิก"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text("ลบ"),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await FirebaseFirestore.instance
                                    .collection('news')
                                    .doc(doc.id)
                                    .delete();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CreateNewsScreen extends StatefulWidget {
  const CreateNewsScreen({super.key});

  @override
  State<CreateNewsScreen> createState() => _CreateNewsScreenState();
}

class _CreateNewsScreenState extends State<CreateNewsScreen> {
  final title = TextEditingController();
  final content = TextEditingController();
  bool loading = false;

  Future<void> _save() async {
    if (title.text.trim().isEmpty || content.text.trim().isEmpty) return;

    setState(() => loading = true);

    await FirebaseFirestore.instance.collection('news').add({
      'title': title.text.trim(),
      'content': content.text.trim(),
      'createdAt': Timestamp.now(),
    });

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pink = Colors.pink.shade300;

    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(title: const Text("สร้างข่าว"), backgroundColor: pink),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'หัวข้อข่าว',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: content,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'เนื้อหา',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: loading ? null : _save,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("โพสต์ข่าว"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔥 หน้าแก้ไขข่าว
class EditNewsScreen extends StatefulWidget {
  final String docId;
  final String oldTitle;
  final String oldContent;

  const EditNewsScreen({
    super.key,
    required this.docId,
    required this.oldTitle,
    required this.oldContent,
  });

  @override
  State<EditNewsScreen> createState() => _EditNewsScreenState();
}

class _EditNewsScreenState extends State<EditNewsScreen> {
  late TextEditingController title;
  late TextEditingController content;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.oldTitle);
    content = TextEditingController(text: widget.oldContent);
  }

  Future<void> _update() async {
    if (title.text.trim().isEmpty || content.text.trim().isEmpty) return;

    setState(() => loading = true);

    await FirebaseFirestore.instance
        .collection('news')
        .doc(widget.docId)
        .update({'title': title.text.trim(), 'content': content.text.trim()});

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pink = Colors.pink.shade300;

    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(title: const Text("แก้ไขข่าว"), backgroundColor: pink),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'หัวข้อข่าว',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: content,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'เนื้อหา',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: loading ? null : _update,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("บันทึกการแก้ไข"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
