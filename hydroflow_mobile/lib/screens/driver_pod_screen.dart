import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DriverPodScreen extends StatefulWidget {
  final String orderId;
  const DriverPodScreen({super.key, required this.orderId});
  @override
  State<DriverPodScreen> createState() => _DriverPodScreenState();
}

class _DriverPodScreenState extends State<DriverPodScreen> {
  int _mode = 0; // 0=photo, 1=signature
  int _empties = 0;
  bool _submitting = false;
  bool _done = false;

  Future<void> _complete() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    // Submit proof — backend marks order DELIVERED automatically
    final proofRes = await ApiService.submitProof(
      widget.orderId,
      emptyCollected: _empties,
    );
    if (!mounted) return;
    if (proofRes['success'] == true) {
      setState(() { _submitting = false; _done = true; });
    } else {
      // Fallback: try plain status update if proof endpoint fails
      final statusRes = await ApiService.updateOrderStatus(widget.orderId, 'DELIVERED');
      if (!mounted) return;
      if (statusRes['success'] == true) {
        setState(() { _submitting = false; _done = true; });
      } else {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(
                      20, MediaQuery.of(context).padding.top + 16, 20, 18),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFeef1f4), width: 1.5),
                          ),
                          child: const Center(
                            child: Icon(Icons.arrow_back_rounded,
                                size: 19, color: Color(0xFF1A1A2E)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Proof of delivery',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Toggle camera / signature
                    Container(
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _TabPill(
                            label: 'Photo',
                            icon: Icons.camera_alt_rounded,
                            selected: _mode == 0,
                            onTap: () => setState(() => _mode = 0),
                          ),
                          _TabPill(
                            label: 'Signature',
                            icon: Icons.draw_rounded,
                            selected: _mode == 1,
                            onTap: () => setState(() => _mode = 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Capture area
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6F8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFe3e8ee),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: const Color(0xFFe3e8ee)),
                              ),
                              child: Center(
                                child: Icon(
                                  _mode == 0
                                      ? Icons.camera_alt_rounded
                                      : Icons.draw_rounded,
                                  color: const Color(0xFF0077B6),
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _mode == 0
                                  ? 'Tap to take a photo'
                                  : 'Tap to sign',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _mode == 0
                                  ? 'Photo of delivered items'
                                  : 'Customer signature',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9aa6b2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Empties counter
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFe3e8ee)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.recycling_rounded,
                              color: Color(0xFFC9742B), size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Empties collected',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                          _Counter(
                            value: _empties,
                            onDecrement: () {
                              if (_empties > 0) setState(() => _empties--);
                            },
                            onIncrement: () => setState(() => _empties++),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Complete button
                    GestureDetector(
                      onTap: _submitting ? null : _complete,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: _submitting
                              ? const Color(0xFFcdd6df)
                              : const Color(0xFF1E9E47),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _submitting
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF1E9E47)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 26,
                                    offset: const Offset(0, 12),
                                    spreadRadius: -10,
                                  ),
                                ],
                        ),
                        child: Center(
                          child: _submitting
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 10),
                                    Text(
                                      'Complete delivery',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),

          // Success overlay
          if (_done)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F8EE),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.check_rounded,
                              color: Color(0xFF1E9E47), size: 42),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Delivery complete!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'The order has been marked as delivered.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6b7785),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // pop POD
                          Navigator.pop(context, true); // pop detail with result
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E9E47),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'Back to deliveries',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TabPill(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? const Color(0xFF0077B6)
                    : const Color(0xFF9aa6b2),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? const Color(0xFF0077B6)
                      : const Color(0xFF9aa6b2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  const _Counter(
      {required this.value,
      required this.onDecrement,
      required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onDecrement,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFe3e8ee)),
            ),
            child: const Center(
              child: Icon(Icons.remove_rounded,
                  size: 16, color: Color(0xFF6b7785)),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Center(
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: onIncrement,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF0077B6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.add_rounded,
                  size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
