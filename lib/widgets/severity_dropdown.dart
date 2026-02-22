import 'package:flutter/material.dart';

class SeverityDropdown extends StatelessWidget {
  static const String allValue = 'ALL';

  final String? value;
  final ValueChanged<String?> onChanged;

  const SeverityDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const severities = <String>['High', 'Medium', 'Low'];

    return DropdownButtonFormField<String>(
      initialValue: value ?? allValue,
      decoration: const InputDecoration(
        labelText: 'Severity',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: allValue,
          child: Text('All Severities'),
        ),
        ...severities.map(
          (s) => DropdownMenuItem<String>(value: s, child: Text(s)),
        ),
      ],
      onChanged: (v) => onChanged(v == allValue ? null : v),
    );
  }
}
