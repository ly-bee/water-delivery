import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'order_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final p = await ApiService.getProducts();
    if (mounted) setState(() { _products = p; _isLoading = false; });
  }

  // Accent colour per product tier (decorative, theme-invariant)
  Color _accentFor(int volume) {
    if (volume <= 20)   return Aq.green;
    if (volume <= 50)   return Aq.driverAvailable;
    if (volume <= 500)  return Aq.accent;
    if (volume <= 1000) return Aq.purple;
    return Aq.driverOnDelivery;
  }

  IconData _iconFor(int volume) {
    if (volume <= 50)  return Icons.water_drop_rounded;
    if (volume <= 500) return Icons.local_drink_rounded;
    return Icons.water_rounded;
  }

  bool _isPopular(int volume) => volume == 50;

  @override
  Widget build(BuildContext context) {
    final aq = Aq.of(context);
    return ColoredBox(
      color: aq.bgPage,
      child: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: aq.accentPositive))
            : RefreshIndicator(
                onRefresh: _load,
                color: aq.accentPositive,
                backgroundColor: aq.bgSurface,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _header()),
                    _products.isEmpty
                        ? SliverFillRemaining(child: _empty())
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _productCard(_products[i]),
                                childCount: _products.length,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _header() {
    final aq = Aq.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Water',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: aq.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fresh delivery to your door',
                    style: TextStyle(fontSize: 13, color: aq.textSecondary),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _load,
              child: Container(
                width: 40, height: 40,
                decoration: Aq.cardDecor(aq, radius: 12),
                child: Icon(Icons.refresh_rounded, color: HfColors.blue, size: 20),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: HfColors.blue.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HfColors.blue.withOpacity(0.15)),
            ),
            child: Row(children: [
              Icon(Icons.bolt_rounded, color: Aq.accent, size: 16),
              const SizedBox(width: 8),
              Text(
                'Same-day delivery · Juja & surrounds',
                style: TextStyle(fontSize: 12, color: aq.textSecondary),
              ),
            ]),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final aq      = Aq.of(context);
    final volume  = product['volume_liters'] as int? ?? 0;
    final price   = double.tryParse(product['price_ksh'].toString()) ?? 0;
    final accent  = _accentFor(volume);
    final popular = _isPopular(volume);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: aq.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: aq.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar
              Container(width: 4, decoration: BoxDecoration(color: accent)),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: accent.withOpacity(0.22)),
                            ),
                            child: Icon(_iconFor(volume), color: accent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                      product['name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w700,
                                        color: aq.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (popular)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Aq.driverOnDelivery.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Aq.driverOnDelivery.withOpacity(0.35)),
                                      ),
                                      child: const Text(
                                        'POPULAR',
                                        style: TextStyle(
                                          fontSize: 9, fontWeight: FontWeight.w800,
                                          color: Aq.driverOnDelivery, letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                ]),
                                const SizedBox(height: 4),
                                Text(
                                  '$volume litres',
                                  style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w900,
                                    color: accent, height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (product['description'] != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          product['description'],
                          style: TextStyle(fontSize: 12, color: aq.textSecondary, height: 1.4),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PRICE',
                              style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: aq.textMuted, letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'KSh ${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900,
                                color: HfColors.blue,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const OrderScreen()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: Aq.gradPrimary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: HfColors.blue.withOpacity(0.3),
                                  blurRadius: 14, offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(children: [
                              Text(
                                'Order',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                            ]),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    final aq = Aq.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.water_drop_outlined, size: 64, color: aq.border),
          const SizedBox(height: 16),
          Text(
            'No products available',
            style: TextStyle(color: aq.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text('Pull down to refresh', style: TextStyle(color: aq.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
