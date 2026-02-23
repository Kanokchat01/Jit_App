import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import 'package:intl/intl.dart';

class EditProfileScreen extends StatefulWidget {
  final AppUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _fs = FirestoreService();

  // ✅ mascot asset (ใช้ตัวเดียวกับหน้า Home)
  static const String _mascotAsset = 'assets/images/jitdee_mascot.png';

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _age;
  late final TextEditingController _birthDate;
  late final TextEditingController _faculty;
  late final TextEditingController _major;
  late final TextEditingController _studentId;
  late final TextEditingController _year;

  String? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _phone = TextEditingController(text: widget.user.phone ?? '');
    _age = TextEditingController(text: widget.user.age ?? '');
    _birthDate = TextEditingController(text: widget.user.birthDate ?? '');
    _faculty = TextEditingController(text: widget.user.faculty ?? '');
    _major = TextEditingController(text: widget.user.major ?? '');
    _studentId = TextEditingController(text: widget.user.studentId ?? '');
    _year = TextEditingController(text: widget.user.year ?? '');
    _gender = widget.user.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _age.dispose();
    _birthDate.dispose();
    _faculty.dispose();
    _major.dispose();
    _studentId.dispose();
    _year.dispose();
    super.dispose();
  }

  InputDecoration _inputStyle(BuildContext context, String label, IconData icon) {
    final cs = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: cs.primary.withOpacity(0.85)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.92),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: cs.primary.withOpacity(0.55), width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.04)),
      ),
      floatingLabelStyle: TextStyle(
        color: cs.primary.withOpacity(0.95),
        fontWeight: FontWeight.w800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSave = !_saving && _name.text.trim().isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.secondary.withOpacity(0.22),
              cs.primary.withOpacity(0.12),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(context),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    children: [
                      _sectionCard(
                        context: context,
                        title: "ข้อมูลพื้นฐาน",
                        subtitle: "อัปเดตข้อมูลให้ครบ เพื่อการประเมินที่แม่นยำ",
                        children: [
                          _disabledEmail(context),
                          const SizedBox(height: 14),

                          TextField(
                            controller: _name,
                            decoration: _inputStyle(
                              context,
                              "ชื่อที่แสดงในระบบ",
                              Icons.person_outline,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 14),

                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: _inputStyle(
                              context,
                              "เบอร์โทร",
                              Icons.phone_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),

                          TextField(
                            controller: _birthDate,
                            readOnly: true,
                            onTap: _pickBirthDate,
                            decoration: _inputStyle(
                              context,
                              "วันเกิด (เลือกจากปฏิทิน)",
                              Icons.calendar_today_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: _inputStyle(context, "เพศ", Icons.wc),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('ชาย')),
                              DropdownMenuItem(value: 'female', child: Text('หญิง')),
                              DropdownMenuItem(value: 'other', child: Text('อื่นๆ')),
                            ],
                            onChanged: (v) => setState(() => _gender = v),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      _sectionCard(
                        context: context,
                        title: "ข้อมูลการศึกษา",
                        subtitle: "ใช้สำหรับจัดกลุ่มข้อมูลและรายงานผล",
                        children: [
                          TextField(
                            controller: _faculty,
                            decoration: _inputStyle(
                              context,
                              "คณะ",
                              Icons.school_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),

                          TextField(
                            controller: _major,
                            decoration: _inputStyle(
                              context,
                              "สาขา",
                              Icons.menu_book_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),

                          TextField(
                            controller: _studentId,
                            decoration: _inputStyle(
                              context,
                              "รหัสนักศึกษา",
                              Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),

                          TextField(
                            controller: _year,
                            keyboardType: TextInputType.number,
                            decoration: _inputStyle(
                              context,
                              "ชั้นปี",
                              Icons.calendar_month_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),
                      _saveButton(context, canSave),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 6),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "แก้ไขข้อมูลส่วนตัว",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.86),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Profile Settings",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.primary.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ mascot เล็ก ๆ ให้มี branding แต่ไม่รบกวน UX
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  _mascotAsset,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.85),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            color: Colors.black.withOpacity(.06),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.3,
              color: Colors.black.withOpacity(0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _disabledEmail(BuildContext context) {
    return TextFormField(
      initialValue: widget.user.email,
      enabled: false,
      decoration: _inputStyle(context, "Email (ไม่สามารถแก้ไขได้)", Icons.email_outlined),
    );
  }

  Widget _saveButton(BuildContext context, bool canSave) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        onPressed: canSave ? _save : null,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary.withOpacity(0.95),
                cs.secondary.withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Text(
                    "บันทึกข้อมูล",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    DateTime initialDate = DateTime(2005);

    if (_birthDate.text.isNotEmpty) {
      try {
        initialDate = DateFormat('dd/MM/yyyy').parse(_birthDate.text);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      _birthDate.text = DateFormat('dd/MM/yyyy').format(picked);
      setState(() {});
    }
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
        birthDate: _birthDate.text,
        faculty: _faculty.text,
        major: _major.text,
        studentId: _studentId.text,
        year: _year.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("บันทึกข้อมูลเรียบร้อย")));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("บันทึกไม่สำเร็จ: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}