import 'package:flutter/material.dart';

class UnFanButton extends StatefulWidget {
  // final Function(bool) onPressed;

  const UnFanButton({
    super.key,
  });

  @override
  State<UnFanButton> createState() => _UnFanButtonState();
}

class _UnFanButtonState extends State<UnFanButton> {
  bool _isFollowing = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing ? Colors.grey[200] : Colors.grey,
          foregroundColor: _isFollowing ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        onPressed: () {
          setState(() {
            // _isFollowing = !_isFollowing;
          });
          // widget.onPressed(_isFollowing);
        },
        child: Text('Unfan'),
      ),
    );
  }
}
