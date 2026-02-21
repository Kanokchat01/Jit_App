import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final String patientId;
  final String? doctorId;
  final DateTime appointmentAt;
  final String status; // pending, approved, rejected, canceled
  final String? note;
  final DateTime? updatedAt;
  final DateTime? requestedAt;

  Appointment({
    required this.id,
    required this.patientId,
    required this.appointmentAt,
    required this.status,
    this.doctorId,
    this.note,
    this.updatedAt,
    this.requestedAt,
  });

  factory Appointment.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Appointment(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'],
      appointmentAt: (data['appointmentAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      note: data['note'],
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      requestedAt: (data['requestedAt'] is Timestamp)
          ? (data['requestedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'appointmentAt': Timestamp.fromDate(appointmentAt),
      'status': status,
      'note': note,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'requestedAt': FieldValue.serverTimestamp(),
    };
  }

  // ============================================================
  // 🔔 แจ้งเตือนแอดมินเมื่อมีการสร้างคำขอนัดใหม่
  // ============================================================
  static Future<void> notifyAdminNewAppointment({
    required String appointmentId,
    required String patientId,
    required String patientName,
    required DateTime appointmentAt,
  }) async {
    final formattedDate =
        "${appointmentAt.day}/${appointmentAt.month}/${appointmentAt.year} "
        "${appointmentAt.hour.toString().padLeft(2, '0')}:"
        "${appointmentAt.minute.toString().padLeft(2, '0')}";

    await FirebaseFirestore.instance.collection('admin_notifications').add({
      'title': 'มีคำขอนัดหมายใหม่',
      'body': 'คุณ $patientName ส่งคำขอนัดวันที่ $formattedDate',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'appointment',
      'appointmentId': appointmentId,
      'patientId': patientId,
    });
  }
}
