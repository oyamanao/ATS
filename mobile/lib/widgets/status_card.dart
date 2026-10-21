import 'package:flutter/material.dart';

enum StatusType { idle, loading, success, failure }

class StatusCard extends StatelessWidget {
  final StatusType status;
  final String message;

  const StatusCard({
    super.key,
    required this.status,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      StatusType.idle => Colors.grey.shade100,
      StatusType.loading => const Color(0xFFEFF6FF),
      StatusType.success => const Color(0xFFF0FDF4),
      StatusType.failure => const Color(0xFFFEF2F2),
    };

    final icon = switch (status) {
      StatusType.idle => Icons.info_outline_rounded,
      StatusType.loading => Icons.sync_rounded,
      StatusType.success => Icons.check_circle_rounded,
      StatusType.failure => Icons.error_outline_rounded,
    };

    final iconColor = switch (status) {
      StatusType.idle => Colors.blueGrey.shade600,
      StatusType.loading => const Color(0xFF2563EB),
      StatusType.success => const Color(0xFF16A34A),
      StatusType.failure => const Color(0xFFDC2626),
    };

    final borderColor = switch (status) {
      StatusType.idle => Colors.grey.shade300,
      StatusType.loading => const Color(0xFFBFDBFE),
      StatusType.success => const Color(0xFFBBF7D0),
      StatusType.failure => const Color(0xFFFECACA),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (status == StatusType.loading)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            )
          else
            Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
