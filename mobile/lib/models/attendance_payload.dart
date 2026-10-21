/// Represents the signed payload sent to the backend for attendance marking.
class AttendancePayload {
  final String qrPayload;
  final String signature;

  const AttendancePayload({
    required this.qrPayload,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'qrPayload': qrPayload,
        'signature': signature,
      };
}
