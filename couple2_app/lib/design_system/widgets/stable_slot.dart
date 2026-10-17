import 'package:flutter/material.dart';

/// One height for the loading, error, and loaded forms of a card or row.
///
/// The child is given a tight height, so a short error card cannot collapse
/// and a taller loaded card cannot push the widgets under it.
class StableSlot extends StatelessWidget {
  const StableSlot({super.key, required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, width: double.infinity, child: child);
  }
}

/// List row and the carinho button. Home card heights live with the home scope.
const listCardSlotHeight = 120.0;
const listItemSlotHeight = 88.0;
const careButtonSlotHeight = 64.0;
