import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';

class AdminAppointmentQueueScreen extends StatefulWidget {
  const AdminAppointmentQueueScreen({super.key});

  @override
  State<AdminAppointmentQueueScreen> createState() =>
      _AdminAppointmentQueueScreenState();
}

class _AdminAppointmentQueueScreenState extends State<AdminAppointmentQueueScreen> {
  final _fs = FirestoreService();
  final _searchCtrl = TextEditingController();

  /// pending | approved | rejected | canceled | completed | all
  String statusFilter = 'pending';

  String get _q => _searchCtrl.text.trim().toLowerCase();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = _fs.watchAppointmentsByStatus(status: statusFilter);

    return Scaffold(
      appBar: AppBar(
        title: const Text('คิวนัดหมายแพทย์'),
      ),
      body: Column(
        children: [
          _topFilters(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
                }

                final items = (snap.data ?? []);

                // ✅ search filter (ชื่อ/uid)
                final filtered = items.where((a) {
                  if (_q.isEmpty) return true;
                  final name = (a['patientName'] ?? '').toString().toLowerCase();
                  final uid = (a['patientUid'] ?? '').toString().toLowerCase();
                  return name.contains(_q) || uid.contains(_q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _q.isEmpty ? 'ไม่มีรายการในสถานะนี้' : 'ไม่พบผลลัพธ์ที่ค้นหา',
                      style: TextStyle(color: Colors.black.withOpacity(0.6)),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _apptCard(context, filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // UI: Top Filters + Search
  // =========================
  Widget _topFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Column(
        children: [
          // Search
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ค้นหา: ชื่อผู้ป่วย / patientUid',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),

          // Status chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusChip('รออนุมัติ', 'pending', tone: _Tone.orange),
                _statusChip('อนุมัติ', 'approved', tone: _Tone.green),
                _statusChip('ปฏิเสธ', 'rejected', tone: _Tone.red),

                // ❌ เอา Chip "ยกเลิก" ออก
                // _statusChip('ยกเลิก', 'canceled', tone: _Tone.grey),

                _statusChip('เสร็จสิ้น', 'completed', tone: _Tone.blueGrey),
                _statusChip('ทั้งหมด', 'all', tone: _Tone.normal),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String value, {required _Tone tone}) {
    final selected = statusFilter == value;
    final color = _toneColor(tone);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => statusFilter = value),
        selectedColor: color.withOpacity(0.16),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: selected ? color : Colors.black.withOpacity(0.7),
        ),
        side: BorderSide(color: color.withOpacity(selected ? 0.35 : 0.18)),
      ),
    );
  }

  // =========================
  // Card
  // =========================
  Widget _apptCard(BuildContext context, Map<String, dynamic> a) {
    final id = (a['id'] ?? '').toString();
    final patientName = (a['patientName'] ?? '-').toString();
    final patientUid = (a['patientUid'] ?? '-').toString();
    final note = (a['note'] ?? '').toString().trim();
    final adminNote = (a['adminNote'] ?? '').toString().trim();
    final status = (a['status'] ?? '').toString().toLowerCase();

    DateTime? dt;
    final apptAt = a['appointmentAt'];
    if (apptAt is Timestamp) dt = apptAt.toDate();
    if (apptAt is DateTime) dt = apptAt;

    final dateText = dt == null
        ? '-'
        : '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}';

    final badge = _statusBadge(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            children: [
              CircleAvatar(
                backgroundColor: badge.color.withOpacity(0.14),
                child: Icon(badge.icon, color: badge.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'วันเวลา: $dateText',
                      style: TextStyle(color: Colors.black.withOpacity(0.65)),
                    ),
                  ],
                ),
              ),
              _pill(badge.text, badge.color),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            'patientUid: $patientUid',
            style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12.5),
          ),

          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            _miniBox(
              title: 'หมายเหตุผู้ป่วย',
              text: note,
              tone: _Tone.normal,
            ),
          ],

          if (adminNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            _miniBox(
              title: 'หมายเหตุแอดมิน/แพทย์',
              text: adminNote,
              tone: _Tone.blueGrey,
            ),
          ],

          const SizedBox(height: 12),

          // actions (เฉพาะ pending เท่านั้นให้กดอนุมัติ/ปฏิเสธเด่น)
          if (status == 'pending') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('อนุมัติ'),
                    onPressed: () async {
                      final note =
                          await _noteDialog(context, 'อนุมัติ', hint: 'ระบุหมายเหตุ (ถ้ามี)');
                      await _fs.updateAppointmentStatus(
                        appointmentId: id,
                        status: 'approved',
                        adminNote: note,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('อนุมัติแล้ว')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('ปฏิเสธ'),
                    onPressed: () async {
                      final reason =
                          await _noteDialog(context, 'ปฏิเสธ', hint: 'ระบุเหตุผล (จำเป็น)');
                      if (reason == null || reason.trim().isEmpty) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('กรุณาใส่เหตุผลก่อน')),
                        );
                        return;
                      }
                      await _fs.updateAppointmentStatus(
                        appointmentId: id,
                        status: 'rejected',
                        adminNote: reason,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ปฏิเสธแล้ว')),
                      );
                    },
                  ),
                ),
              ],
            ),

            // ❌ เอาปุ่ม “ยกเลิกคำขอ” ออกตรงนี้แล้ว
            // const SizedBox(height: 10),
            // Align(
            //   alignment: Alignment.centerLeft,
            //   child: TextButton.icon(
            //     icon: const Icon(Icons.block),
            //     label: const Text('ยกเลิกคำขอ'),
            //     onPressed: () async {...},
            //   ),
            // ),
          ] else ...[
            // ถ้าไม่ใช่ pending: ให้ปุ่ม “ทำเครื่องหมายเสร็จสิ้น” (เฉพาะ approved/confirmed)
            Row(
              children: [
                if (status == 'approved' || status == 'confirmed') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.verified),
                      label: const Text('ทำเครื่องหมายเสร็จสิ้น'),
                      onPressed: () async {
                        final ok = await _confirm(
                            context, 'เสร็จสิ้น', 'ยืนยันทำเครื่องหมาย “เสร็จสิ้น” ?');
                        if (ok != true) return;

                        await _fs.updateAppointmentStatus(
                          appointmentId: id,
                          status: 'completed',
                          adminNote: 'เสร็จสิ้นโดยแอดมิน',
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('อัปเดตเป็นเสร็จสิ้นแล้ว')),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_note),
                      label: const Text('เพิ่มหมายเหตุ'),
                      onPressed: () async {
                        final note = await _noteDialog(context, 'เพิ่มหมายเหตุ', hint: 'บันทึกหมายเหตุ');
                        if (note == null || note.trim().isEmpty) return;

                        await _fs.updateAppointmentStatus(
                          appointmentId: id,
                          status: status, // ไม่เปลี่ยนสถานะ
                          adminNote: note,
                          appendNote: true,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('บันทึกหมายเหตุแล้ว')),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // =========================
  // Helpers
  // =========================
  Future<String?> _noteDialog(BuildContext context, String title, {String? hint}) async {
    final controller = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint ?? 'หมายเหตุ',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    return res;
  }

  Future<bool?> _confirm(BuildContext context, String title, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('ยืนยัน')),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 12),
      ),
    );
  }

  Widget _miniBox({required String title, required String text, required _Tone tone}) {
    final c = _toneColor(tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: c)),
          const SizedBox(height: 4),
          Text(text),
        ],
      ),
    );
  }

  _Badge _statusBadge(String status) {
    switch (status) {
      case 'pending':
        return _Badge('PENDING', 'รออนุมัติ', Icons.hourglass_top, Colors.orange);
      case 'approved':
      case 'confirmed':
        return _Badge('APPROVED', 'อนุมัติแล้ว', Icons.check_circle, Colors.green);
      case 'rejected':
        return _Badge('REJECTED', 'ปฏิเสธ', Icons.cancel, Colors.red);
      case 'canceled':
        return _Badge('CANCELED', 'ยกเลิก', Icons.block, Colors.grey);
      case 'completed':
        return _Badge('COMPLETED', 'เสร็จสิ้น', Icons.verified, Colors.blueGrey);
      default:
        return _Badge('STATUS', status, Icons.info, Colors.blueGrey);
    }
  }

  Color _toneColor(_Tone t) {
    switch (t) {
      case _Tone.red:
        return Colors.red;
      case _Tone.orange:
        return Colors.orange;
      case _Tone.green:
        return Colors.green;
      case _Tone.grey:
        return Colors.grey;
      case _Tone.blueGrey:
        return Colors.blueGrey;
      default:
        return Colors.blueGrey;
    }
  }
}

enum _Tone { normal, orange, green, red, grey, blueGrey }

class _Badge {
  final String key;
  final String text;
  final IconData icon;
  final Color color;
  _Badge(this.key, this.text, this.icon, this.color);
}
