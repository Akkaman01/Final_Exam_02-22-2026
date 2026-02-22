import 'package:flutter/material.dart';

class StationEditAlertDialog extends StatelessWidget {
  final int incidentCount;

  const StationEditAlertDialog({
    super.key,
    required this.incidentCount,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ยืนยันการแก้ไขข้อมูล'),
      content: Text(
        'หน่วยนี้มีประวัติร้องเรียน $incidentCount เรื่อง ยืนยันการแก้ไขข้อมูลหรือไม่?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
