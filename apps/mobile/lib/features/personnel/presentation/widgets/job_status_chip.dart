import "package:flutter/material.dart";

class JobStatusChip extends StatelessWidget {
  const JobStatusChip({super.key, required this.status});

  final String status;

  Color _backgroundColor(BuildContext context) {
    switch (status) {
      case "PENDING":
        return Colors.blue.shade100;
      case "IN_PROGRESS":
        return Colors.orange.shade100;
      case "DELIVERED":
        return Colors.grey.shade300;
      case "ARCHIVED":
        return Colors.green.shade100;
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
