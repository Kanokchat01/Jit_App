import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminNewsScreen extends StatelessWidget {
  const AdminNewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ธีมสีให้ใกล้เคียง JitDee (มิ้นท์)
    final mint = const Color(0xFF35CDB8);
    final bg = const Color(0xFFF3FBFA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "จัดการข่าวสาร",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        foregroundColor: Colors.black.withOpacity(0.85),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: mint,
        elevation: 6,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateNewsScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Header Card สวย ๆ
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [
                    mint.withOpacity(0.18),
                    Colors.white.withOpacity(0.92),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: mint.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: mint.withOpacity(0.22)),
                    ),
                    child: Icon(Icons.campaign_outlined, color: mint),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'News Management',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black.withOpacity(0.84),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'สร้าง • แก้ไข • ลบ ข่าวสารเพื่อผู้ใช้งาน',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.60),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: mint.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: mint.withOpacity(0.22)),
                    ),
                    child: Text(
                      'ADMIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: mint,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('news')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: mint),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 44, color: Colors.black.withOpacity(0.35)),
                          const SizedBox(height: 10),
                          Text(
                            "ยังไม่มีข่าว",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black.withOpacity(0.75),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "กดปุ่ม + เพื่อสร้างข่าวแรกของคุณ",
                            style: TextStyle(color: Colors.black.withOpacity(0.55)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: Colors.white.withOpacity(0.94),
                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: mint.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: mint.withOpacity(0.22)),
                                  ),
                                  child: Icon(Icons.article_outlined, color: mint),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    (data['title'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black.withOpacity(0.86),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            Text(
                              (data['content'] ?? '').toString(),
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.68),
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 12),
                            Container(height: 1, color: Colors.black.withOpacity(0.06)),
                            const SizedBox(height: 10),

                            // เวลา + ปุ่ม Edit/Delete
                            Row(
                              children: [
                                if (formattedDate.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.black.withOpacity(0.45),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black.withOpacity(0.55),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                const Spacer(),

                                _pillButton(
                                  label: 'Edit',
                                  icon: Icons.edit,
                                  color: mint,
                                  onTap: () {
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
                                _pillButton(
                                  label: 'Delete',
                                  icon: Icons.delete,
                                  color: Colors.red,
                                  onTap: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        title: const Text(
                                          "ลบโพสต์",
                                          style: TextStyle(fontWeight: FontWeight.w900),
                                        ),
                                        content: const Text(
                                          "คุณแน่ใจหรือไม่ว่าต้องการลบโพสต์นี้",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text("ยกเลิก"),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                            ),
                                            onPressed: () => Navigator.pop(context, true),
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
          ),
        ],
      ),
    );
  }

  // ปุ่มทรง pill ใช้ซ้ำ
  static Widget _pillButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.26)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
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
    final mint = const Color(0xFF35CDB8);
    final bg = const Color(0xFFF3FBFA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black.withOpacity(0.85),
        title: const Text(
          "สร้างข่าว",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            _formCard(
              mint: mint,
              child: Column(
                children: [
                  _prettyTextField(
                    controller: title,
                    label: 'หัวข้อข่าว',
                    icon: Icons.title,
                    mint: mint,
                  ),
                  const SizedBox(height: 14),
                  _prettyTextField(
                    controller: content,
                    label: 'เนื้อหา',
                    icon: Icons.article_outlined,
                    mint: mint,
                    maxLines: 6,
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mint,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: loading ? null : _save,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "โพสต์ข่าว",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _formCard({required Color mint, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.94),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  static Widget _prettyTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color mint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: mint.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: mint.withOpacity(0.40), width: 1.2),
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
    final mint = const Color(0xFF35CDB8);
    final bg = const Color(0xFFF3FBFA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black.withOpacity(0.85),
        title: const Text(
          "แก้ไขข่าว",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            _CreateNewsScreenState._formCard(
              mint: mint,
              child: Column(
                children: [
                  _CreateNewsScreenState._prettyTextField(
                    controller: title,
                    label: 'หัวข้อข่าว',
                    icon: Icons.title,
                    mint: mint,
                  ),
                  const SizedBox(height: 14),
                  _CreateNewsScreenState._prettyTextField(
                    controller: content,
                    label: 'เนื้อหา',
                    icon: Icons.article_outlined,
                    mint: mint,
                    maxLines: 6,
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mint,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: loading ? null : _update,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "บันทึกการแก้ไข",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}