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
  final _db = FirebaseFirestore.instance;

  /// pending | approved | rejected | canceled | completed | all
  String statusFilter = 'pending';

  String get _q => _searchCtrl.text.trim().toLowerCase();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPatientNotification({
    required String patientUid,
    required String apptId,
    required String title,
    required String body,
  }) async {
    if (patientUid.trim().isEmpty) return;

    await _db
        .collection('users')
        .doc(patientUid)
        .collection('notifications')
        .add({
      'type': 'appointment_status',
      'apptId': apptId,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stream = _fs.watchAppointmentsByStatus(status: statusFilter);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary.withOpacity(0.08),
              cs.secondary.withOpacity(0.10),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(context),
              _topFiltersCard(context),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            'เกิดข้อผิดพลาด: ${snap.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black.withOpacity(0.70)),
                          ),
                        ),
                      );
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
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 42, color: Colors.black.withOpacity(0.35)),
                              const SizedBox(height: 10),
                              Text(
                                _q.isEmpty ? 'ไม่มีรายการในสถานะนี้' : 'ไม่พบผลลัพธ์ที่ค้นหา',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black.withOpacity(0.70),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ลองเปลี่ยนสถานะ หรือปรับคำค้นหาใหม่',
                                style: TextStyle(color: Colors.black.withOpacity(0.55)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _apptCard(context, filtered[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // UI: Top Bar
  // =========================
  Widget _topBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    color: Colors.black.withOpacity(0.06),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back, color: Colors.black.withOpacity(0.75)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin · JitDee',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black.withOpacity(0.82),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'คิวนัดหมายแพทย์',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.black.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.primary.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Icon(Icons.queue_outlined, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Queue',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // UI: Top Filters + Search (card)
  // =========================
  Widget _topFiltersCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.05),
            ),
          ],
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
                filled: true,
                fillColor: cs.primary.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.35), width: 1.2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Status chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _statusChip('รออนุมัติ', 'pending', tone: _Tone.orange),
                  _statusChip('อนุมัติ', 'approved', tone: _Tone.green),
                  _statusChip('ปฏิเสธ', 'rejected', tone: _Tone.red),
                  _statusChip('เสร็จสิ้น', 'completed', tone: _Tone.blueGrey),
                  _statusChip('ทั้งหมด', 'all', tone: _Tone.normal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, String value, {required _Tone tone}) {
    final cs = Theme.of(context).colorScheme;
    final selected = statusFilter == value;
    final color = _toneColor(tone);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => statusFilter = value),
        selectedColor: color.withOpacity(0.18),
        backgroundColor: cs.primary.withOpacity(0.04),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w900,
          color: selected ? color : Colors.black.withOpacity(0.70),
        ),
        side: BorderSide(
          color: color.withOpacity(selected ? 0.35 : 0.18),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  // =========================
  // Card (ตกแต่งใหม่ แต่ logic เดิม)
  // =========================
  Widget _apptCard(BuildContext context, Map<String, dynamic> a) {
    final cs = Theme.of(context).colorScheme;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badge.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: badge.color.withOpacity(0.22)),
                ),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dateText,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.65),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
            style: TextStyle(
              color: Colors.black.withOpacity(0.55),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),

          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            _miniBox(
              title: 'หมายเหตุผู้ป่วย',
              text: note,
              tone: _Tone.normal,
            ),
          ],

          if (adminNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            _miniBox(
              title: 'หมายเหตุแอดมิน/แพทย์',
              text: adminNote,
              tone: _Tone.blueGrey,
            ),
          ],

          const SizedBox(height: 12),
          Container(height: 1, color: Colors.black.withOpacity(0.06)),
          const SizedBox(height: 12),

          // actions
          if (status == 'pending') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('อนุมัติ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      final note =
                          await _noteDialog(context, 'อนุมัติ', hint: 'ระบุหมายเหตุ (ถ้ามี)');

                      await _fs.updateAppointmentStatus(
                        appointmentId: id,
                        status: 'approved',
                        adminNote: note,
                      );

                      // ✅ สร้าง in-app notification ให้ผู้ป่วย
                      final body = (note != null && note.trim().isNotEmpty)
                          ? 'แพทย์อนุมัติแล้ว: ${note.trim()}'
                          : 'แพทย์อนุมัติแล้ว กรุณาตรวจสอบวันนัดในระบบ';

                      await _addPatientNotification(
                        patientUid: patientUid,
                        apptId: id,
                        title: 'คำขอนัดได้รับการอนุมัติ',
                        body: body,
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.red.withOpacity(0.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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

                      // ✅ สร้าง in-app notification ให้ผู้ป่วย
                      await _addPatientNotification(
                        patientUid: patientUid,
                        apptId: id,
                        title: 'คำขอนัดถูกปฏิเสธ',
                        body: 'เหตุผล: ${reason.trim()}',
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
          ] else ...[
            Row(
              children: [
                if (status == 'approved' || status == 'confirmed') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.verified),
                      label: const Text('ทำเครื่องหมายเสร็จสิ้น'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        final ok = await _confirm(
                            context, 'เสร็จสิ้น', 'ยืนยันทำเครื่องหมาย “เสร็จสิ้น” ?');
                        if (ok != true) return;

                        await _fs.updateAppointmentStatus(
                          appointmentId: id,
                          status: 'completed',
                          adminNote: 'เสร็จสิ้นโดยแอดมิน',
                        );

                        // (ถ้าคุณไม่อยากแจ้งเตือนตอน completed ให้ลบบล็อกนี้ออกได้)
                        await _addPatientNotification(
                          patientUid: patientUid,
                          apptId: id,
                          title: 'การนัดหมายเสร็จสิ้น',
                          body: 'การนัดหมายถูกทำเครื่องหมายว่าเสร็จสิ้นแล้ว',
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: cs.primary.withOpacity(0.30)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        final note =
                            await _noteDialog(context, 'เพิ่มหมายเหตุ', hint: 'บันทึกหมายเหตุ');
                        if (note == null || note.trim().isEmpty) return;

                        await _fs.updateAppointmentStatus(
                          appointmentId: id,
                          status: status,
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
  // Helpers (เดิม)
  // =========================
  Future<String?> _noteDialog(BuildContext context, String title, {String? hint}) async {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint ?? 'หมายเหตุ',
            filled: true,
            fillColor: cs.primary.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.primary.withOpacity(0.35), width: 1.2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    return res;
  }

  Future<bool?> _confirm(BuildContext context, String title, String msg) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 12),
      ),
    );
  }

  Widget _miniBox({required String title, required String text, required _Tone tone}) {
    final cs = Theme.of(context).colorScheme;
    final c = _toneColor(tone);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: c)),
              const Spacer(),
              Icon(Icons.notes, size: 16, color: cs.primary.withOpacity(0.55)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(color: Colors.black.withOpacity(0.78)),
          ),
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