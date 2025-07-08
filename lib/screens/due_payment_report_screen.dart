import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DuePaymentReportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [FadeEffect(duration: 600.ms), MoveEffect(begin: Offset(0, 30))],
      child: Scaffold(
        appBar: AppBar(title: Text('Due Payment Report')),
        body: Center(
          child: Text(
            'Due Payment Report content goes here.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
