import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
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
  bool _capturing = false;

  Uint8List? _photoBytes;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: const Color(0xFF1A1A2E),
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => _photoBytes = bytes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open camera'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _complete() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final signatureBytes = _signatureController.isNotEmpty
        ? await _signatureController.toPngBytes()
        : null;
    // Submit proof — backend uploads any captured photo/signature to Cloudinary
    // and marks the order DELIVERED automatically.
    final proofRes = await ApiService.submitProof(
      widget.orderId,
      emptyCollected: _empties,
      photoBytes: _photoBytes,
      signatureBytes: signatureBytes,
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

  Widget _buildPhotoCapture() {
    if (_photoBytes == null) {
      return GestureDetector(
        onTap: _capturePhoto,
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFe3e8ee), width: 1.5),
          ),
          child: Center(
            child: _capturing
                ? const CircularProgressIndicator(
                    color: Color(0xFF0077B6), strokeWidth: 2)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border:
                              Border.all(color: const Color(0xFFe3e8ee)),
                        ),
                        child: const Center(
                          child: Icon(Icons.camera_alt_rounded,
                              color: Color(0xFF0077B6), size: 26),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tap to take a photo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Photo of delivered items',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF9aa6b2)),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.black12,
              child: Image.memory(_photoBytes!, fit: BoxFit.cover),
            ),
            Positioned(
              top: 10, right: 10,
              child: GestureDetector(
                onTap: _capturePhoto,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 14, color: Colors.white),
                      SizedBox(width: 5),
                      Text('Retake',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureCapture() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFe3e8ee), width: 1.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Signature(
            controller: _signatureController,
            height: 220,
            backgroundColor: Colors.white,
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _signatureController,
              builder: (_, __) {
                if (_signatureController.isNotEmpty) return const SizedBox.shrink();
                return const Center(
                  child: Text(
                    'Sign above',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9aa6b2)),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 10, right: 10,
            child: AnimatedBuilder(
              animation: _signatureController,
              builder: (_, __) {
                if (_signatureController.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => _signatureController.clear(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6F8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFe3e8ee)),
                    ),
                    child: const Text('Clear',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6b7785))),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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
                    _mode == 0 ? _buildPhotoCapture() : _buildSignatureCapture(),
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
