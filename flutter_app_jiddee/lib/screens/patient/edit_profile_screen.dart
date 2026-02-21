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

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_saving && _name.text.trim().isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F3FF), Color(0xFFE0F2FE), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _sectionCard(
                        title: "ข้อมูลพื้นฐาน",
                        children: [
                          _disabledEmail(),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _name,
                            decoration: _inputStyle(
                              "ชื่อที่แสดงในระบบ",
                              Icons.person,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: _inputStyle("เบอร์โทร", Icons.phone),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _birthDate,
                            readOnly: true,
                            onTap: _pickBirthDate,
                            decoration: _inputStyle(
                              "วันเกิด (เลือกจากปฏิทิน)",
                              Icons.calendar_today,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: _inputStyle("เพศ", Icons.wc),
                            items: const [
                              DropdownMenuItem(
                                value: 'male',
                                child: Text('ชาย'),
                              ),
                              DropdownMenuItem(
                                value: 'female',
                                child: Text('หญิง'),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text('อื่นๆ'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _gender = v),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _sectionCard(
                        title: "ข้อมูลการศึกษา",
                        children: [
                          TextField(
                            controller: _faculty,
                            decoration: _inputStyle("คณะ", Icons.school),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _major,
                            decoration: _inputStyle("สาขา", Icons.menu_book),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _studentId,
                            decoration: _inputStyle(
                              "รหัสนักศึกษา",
                              Icons.badge,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _year,
                            keyboardType: TextInputType.number,
                            decoration: _inputStyle("ชั้นปี", Icons.school),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      _saveButton(canSave),
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            "แก้ไขข้อมูลส่วนตัว",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withOpacity(.05),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _disabledEmail() {
    return TextFormField(
      initialValue: widget.user.email,
      enabled: false,
      decoration: _inputStyle("Email (ไม่สามารถแก้ไขได้)", Icons.email),
    );
  }

  Widget _saveButton(bool canSave) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        onPressed: canSave ? _save : null,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
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
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "บันทึกข้อมูล",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("บันทึกข้อมูลเรียบร้อย")));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("บันทึกไม่สำเร็จ: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
