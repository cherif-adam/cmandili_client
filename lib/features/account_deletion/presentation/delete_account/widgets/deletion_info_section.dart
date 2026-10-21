import 'package:flutter/material.dart';

/// Une liste titrée de la carte d'explication (supprimé / gardé).
class DeletionInfoSection extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<String> lines;

  const DeletionInfoSection({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: width * 0.04,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: width * 0.02),
        for (final line in lines)
          Padding(
            padding: EdgeInsets.only(bottom: width * 0.015),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: width * 0.045, color: color),
                SizedBox(width: width * 0.025),
                Expanded(
                  child: Text(line, style: TextStyle(fontSize: width * 0.036)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
