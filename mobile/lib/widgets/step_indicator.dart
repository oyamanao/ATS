import 'package:flutter/material.dart';

enum StepStatus { pending, active, success, failed }

class VerificationStep {
  final String label;
  final String description;
  final StepStatus status;

  const VerificationStep({
    required this.label,
    this.description = '',
    required this.status,
  });
}

class StepIndicator extends StatelessWidget {
  final List<VerificationStep> steps;

  const StepIndicator({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final isLast = index == steps.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    _buildDot(step.status),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: step.status == StepStatus.success
                              ? const Color(0xFF16A34A).withValues(alpha: 0.4)
                              : Colors.grey.shade200,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: step.status == StepStatus.active
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: step.status == StepStatus.pending
                                ? Colors.grey.shade400
                                : step.status == StepStatus.failed
                                    ? const Color(0xFFDC2626)
                                    : Colors.grey.shade900,
                          ),
                        ),
                        if (step.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            step.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDot(StepStatus status) {
    return switch (status) {
      StepStatus.pending => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
        ),
      StepStatus.active => const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
          ),
        ),
      StepStatus.success => const Icon(
          Icons.check_circle_rounded,
          size: 22,
          color: Color(0xFF16A34A),
        ),
      StepStatus.failed => const Icon(
          Icons.cancel_rounded,
          size: 22,
          color: Color(0xFFDC2626),
        ),
    };
  }
}
