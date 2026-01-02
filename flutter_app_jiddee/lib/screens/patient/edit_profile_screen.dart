import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';

class EditProfileScreen extends StatefulWidget {
  final AppUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _fs = FirestoreService();

  late final TextEditingController _name;
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _age = TextEditingController();
  String? _gender;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_saving && _name.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลส่วนตัว'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.blueGrey.withOpacity(0.08),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.18)),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Icon(Icons.local_hospital),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ข้อมูลส่วนตัวของคุณ\nใช้เพื่อช่วยในการดูแลและติดต่อกลับเมื่อจำเป็น',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'ชื่อที่แสดงในระบบ',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'เบอร์โทร (ไม่บังคับ)',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'อายุ (ไม่บังคับ)',
                prefixIcon: Icon(Icons.cake),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(
                labelText: 'เพศ (ไม่บังคับ)',
                prefixIcon: Icon(Icons.wc),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('ชาย')),
                DropdownMenuItem(value: 'female', child: Text('หญิง')),
                DropdownMenuItem(value: 'other', child: Text('อื่นๆ')),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                onPressed: canSave ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _fs.updateUserProfile(
        uid: widget.user.uid,
        name: _name.text,
        phone: _phone.text,
        age: _age.text,
        gender: _gender,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อย')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
