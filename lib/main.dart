import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const PriceLensApp());
}

// ─── CONFIG ───────────────────────────────────────────────────────────────────

class ApiConfig {
  // Android emulator: 10.0.2.2  |  iOS simulator / real device: your machine IP
  static const String baseUrl = 'http://10.0.2.2:8000';
}

// ─── THEME ────────────────────────────────────────────────────────────────────

class AppColors {
  static const bg          = Color(0xFF0A0F1E);
  static const surface     = Color(0xFF111827);
  static const card        = Color(0xFF1A2235);
  static const cardBorder  = Color(0xFF253047);
  static const teal        = Color(0xFF00C9A7);
  static const tealDark    = Color(0xFF009E84);
  static const amber       = Color(0xFFFFC542);
  static const red         = Color(0xFFFF6B6B);
  static const textPrimary = Color(0xFFF0F4FF);
  static const textSecondary = Color(0xFF8896B0);
  static const textMuted   = Color(0xFF4A5568);
  static const green       = Color(0xFF4ADE80);
  static const blue        = Color(0xFF60A5FA);
}

// ─── MODELS ───────────────────────────────────────────────────────────────────

class PriceEntry {
  final String storeName;
  final String storeType;
  final double price;
  final String currency;
  final bool inStock;
  final double? rating;
  final String? storeUrl;

  const PriceEntry({
    required this.storeName,
    required this.storeType,
    required this.price,
    this.currency = 'PKR',
    this.inStock = true,
    this.rating,
    this.storeUrl,
  });

  factory PriceEntry.fromJson(Map<String, dynamic> j) => PriceEntry(
        storeName: j['store_name'] ?? '',
        storeType: j['store_type'] ?? 'local',
        price:     (j['price'] as num).toDouble(),
        currency:  j['currency'] ?? 'PKR',
        inStock:   j['in_stock'] ?? true,
        rating:    j['rating'] != null ? (j['rating'] as num).toDouble() : null,
        storeUrl:  j['store_url'],
      );

  // emoji helper based on store name
  String get logoEmoji {
    final n = storeName.toLowerCase();
    if (n.contains('daraz'))    return '📦';
    if (n.contains('goto'))     return '🛍️';
    if (n.contains('homeshop')) return '💻';
    if (n.contains('carrefour')) return '🛒';
    if (n.contains('izone'))    return '📱';
    if (n.contains('metro'))    return '🏬';
    if (n.contains('imtiaz'))   return '🏪';
    if (n.contains('naheed'))   return '🏬';
    if (n.contains('al-fatah')) return '🏪';
    return storeType == 'online' ? '🌐' : '🏪';
  }
}

class ProductInfo {
  final String id;
  final String name;
  final String barcode;
  final String category;
  final String? brand;

  const ProductInfo({
    required this.id,
    required this.name,
    required this.barcode,
    required this.category,
    this.brand,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> j) => ProductInfo(
        id:       j['id'] ?? '',
        name:     j['name'] ?? '',
        barcode:  j['barcode'] ?? '',
        category: j['category'] ?? '',
        brand:    j['brand'],
      );

  String get emoji {
    switch (category.toLowerCase()) {
      case 'beverages': return '🥤';
      case 'electronics': return '🎧';
      case 'household': return '🧼';
      case 'snacks': return '🍟';
      default: return '📦';
    }
  }
}

class PriceComparison {
  final ProductInfo product;
  final List<PriceEntry> prices;
  final PriceEntry cheapest;
  final double minPrice;
  final double maxPrice;
  final double difference;
  final int storeCount;
  final DateTime fetchedAt;

  const PriceComparison({
    required this.product,
    required this.prices,
    required this.cheapest,
    required this.minPrice,
    required this.maxPrice,
    required this.difference,
    required this.storeCount,
    required this.fetchedAt,
  });

  factory PriceComparison.fromJson(Map<String, dynamic> j) {
    final prices  = (j['prices'] as List).map((e) => PriceEntry.fromJson(e)).toList();
    final range   = j['price_range'] as Map<String, dynamic>;
    return PriceComparison(
      product:    ProductInfo.fromJson(j['product']),
      prices:     prices,
      cheapest:   PriceEntry.fromJson(j['cheapest']),
      minPrice:   (range['min'] as num).toDouble(),
      maxPrice:   (range['max'] as num).toDouble(),
      difference: (range['difference'] as num).toDouble(),
      storeCount: j['store_count'] ?? prices.length,
      fetchedAt:  DateTime.tryParse(j['fetched_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class HistoryItem {
  final String id;
  final String barcode;
  final String productName;
  final String category;
  final double bestPrice;
  final int storeCount;
  final DateTime scannedAt;

  const HistoryItem({
    required this.id,
    required this.barcode,
    required this.productName,
    required this.category,
    required this.bestPrice,
    required this.storeCount,
    required this.scannedAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        id:          j['id'] ?? '',
        barcode:     j['barcode'] ?? '',
        productName: j['product_name'] ?? '',
        category:    j['category'] ?? '',
        bestPrice:   (j['best_price'] as num).toDouble(),
        storeCount:  j['store_count'] ?? 0,
        scannedAt:   DateTime.tryParse(j['scanned_at'] ?? '') ?? DateTime.now(),
      );

  String get emoji {
    switch (category.toLowerCase()) {
      case 'beverages': return '🥤';
      case 'electronics': return '🎧';
      case 'household': return '🧼';
      case 'snacks': return '🍟';
      default: return '📦';
    }
  }
}

// ─── API SERVICE ──────────────────────────────────────────────────────────────

class ApiService {
  static final _client = http.Client();
  
  static var http;

  static Future<PriceComparison> fetchPrices(String barcode) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/prices/$barcode');
    final res = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      return PriceComparison.fromJson(json.decode(res.body));
    }
    final detail = json.decode(res.body)['detail'] ?? 'Unknown error';
    throw ApiException(res.statusCode, detail.toString());
  }

  static Future<List<ProductInfo>> searchProducts(String query) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/products/').replace(
      queryParameters: {'q': query},
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final list = json.decode(res.body) as List;
      return list.map((e) => ProductInfo.fromJson(e)).toList();
    }
    throw ApiException(res.statusCode, 'No products found for "$query"');
  }

  static Future<void> saveScan(String barcode) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/history/scan/$barcode');
    await _client.post(uri).timeout(const Duration(seconds: 6));
  }

  static Future<List<HistoryItem>> fetchHistory() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/history/');
    final res = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      final list = body['history'] as List;
      return list.map((e) => HistoryItem.fromJson(e)).toList();
    }
    throw ApiException(res.statusCode, 'Failed to load history');
  }

  static Future<void> deleteHistoryItem(String id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/history/$id');
    await _client.delete(uri).timeout(const Duration(seconds: 6));
  }

  static Future<void> clearHistory() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/history/');
    await _client.delete(uri).timeout(const Duration(seconds: 6));
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ─── DEMO BARCODES (used by scanner simulation) ───────────────────────────────

const List<String> _demoBarcodes = [
  '8901030784232', // Milo
  '8806094392685', // Samsung Buds
  '8901030560089', // Surf Excel
  '6291003516070', // Lays
  '8901063152090', // Lipton
];

// ─── STATIC NOTIFICATIONS (no backend endpoint) ──────────────────────────────

final List<Map<String, dynamic>> _staticNotifications = [
  {'icon': '📉', 'title': 'Price Drop Alert!',   'body': 'Nestle Milo 400g dropped to PKR 570 on Daraz.pk',             'time': '10 min ago', 'isNew': true},
  {'icon': '🔔', 'title': 'New Local Offer',      'body': 'Carrefour has a weekend sale on electronics — up to 20% off', 'time': '2 hrs ago',  'isNew': true},
  {'icon': '📊', 'title': 'Weekly Summary',       'body': 'You saved PKR 1,240 this week using PriceLens',               'time': '1 day ago',  'isNew': false},
  {'icon': '⚡', 'title': 'Flash Deal',           'body': 'Samsung Galaxy Buds at PKR 15,999 — limited time on Goto.pk', 'time': '2 days ago', 'isNew': false},
];

// ─── APP ROOT ─────────────────────────────────────────────────────────────────

class PriceLensApp extends StatelessWidget {
  const PriceLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PriceLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.teal,
          secondary: AppColors.amber,
          surface: AppColors.surface,
          background: AppColors.bg,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ─── MAIN SHELL ───────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _jumpTo(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onScanTap: () => _jumpTo(1)),
      ScannerScreen(onHistoryTap: () => _jumpTo(2)),
      const HistoryScreen(),
      const NotificationsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.cardBorder)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, 'Home'),
              _navItem(1, Icons.qr_code_scanner_rounded, 'Scan'),
              _navItem(2, Icons.history_rounded, 'History'),
              _navItem(3, Icons.notifications_rounded, 'Alerts'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final active = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: active ? AppColors.teal.withOpacity(0.12) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? AppColors.teal : AppColors.textMuted, size: 24),
            const SizedBox(height: 3),
            Text(label,
              style: TextStyle(
                color: active ? AppColors.teal : AppColors.textMuted,
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── HOME SCREEN ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final VoidCallback onScanTap;
  const HomeScreen({super.key, required this.onScanTap});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<HistoryItem> _recent = [];
  bool _loadingRecent = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    try {
      final items = await ApiService.fetchHistory();
      if (mounted) setState(() { _recent = items.take(3).toList(); _loadingRecent = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          _appBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _hero(),
                const SizedBox(height: 28),
                _statsRow(),
                const SizedBox(height: 28),
                _sectionTitle('Quick Actions'),
                const SizedBox(height: 14),
                _quickActions(),
                const SizedBox(height: 28),
                _sectionTitle('Recent Scans'),
                const SizedBox(height: 14),
                _recentScans(),
                const SizedBox(height: 28),
                _sectionTitle('Top Savings Today'),
                const SizedBox(height: 14),
                _savingsTips(),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _appBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppColors.bg,
      title: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.teal, AppColors.tealDark]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lens, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(children: [
              TextSpan(text: 'Price', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              TextSpan(text: 'Lens',  style: TextStyle(color: AppColors.teal,        fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ]),
          ),
        ],
      ),
      actions: [
        Stack(children: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 26), onPressed: () {}),
          Positioned(right: 10, top: 10, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle))),
        ]),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF003D30), Color(0xFF001A24)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.teal.withOpacity(0.4))),
                  child: const Text('🇵🇰  Pakistan Markets', style: TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                ),
                const SizedBox(height: 12),
                const Text('Compare Prices,\nSave Smarter',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.3)),
                const SizedBox(height: 8),
                const Text('Scan any product barcode & instantly compare across local shops and online stores.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: widget.onScanTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.teal, AppColors.tealDark]), borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Start Scanning', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Text('🔍', style: TextStyle(fontSize: 64)),
        ],
      ),
    );
  }

  Widget _statsRow() {
    final scanCount = _recent.length;
    final totalSaved = _recent.fold(0.0, (sum, _) => sum);
    return Row(
      children: [
        _statCard(scanCount.toString(), 'Scans Today', Icons.qr_code_rounded, AppColors.teal),
        const SizedBox(width: 12),
        _statCard('PKR ${totalSaved > 0 ? totalSaved.toStringAsFixed(0) : "—"}', 'Saved Today', Icons.savings_rounded, AppColors.amber),
        const SizedBox(width: 12),
        _statCard('5', 'Products DB', Icons.store_rounded, AppColors.blue),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2));

  Widget _quickActions() {
    final actions = [
      {'icon': '📷', 'label': 'Scan\nBarcode'},
      {'icon': '🔍', 'label': 'Search\nProduct'},
      {'icon': '📊', 'label': 'Price\nTrends'},
      {'icon': '⭐', 'label': 'Best\nDeals'},
    ];
    return Row(
      children: actions.asMap().entries.map((e) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: e.key < actions.length - 1 ? 10 : 0),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
            child: Column(
              children: [
                Text(e.value['icon']!, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 6),
                Text(e.value['label']!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _recentScans() {
    if (_loadingRecent) {
      return _shimmerList(2);
    }
    if (_recent.isEmpty) {
      return _emptyCard('No scans yet. Tap Scan to get started!', '📷');
    }
    return Column(
      children: _recent.map((item) {
        return GestureDetector(
          onTap: () => _openScan(item.barcode),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text('${item.storeCount} stores compared', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Text('PKR ${item.bestPrice.toStringAsFixed(0)}',
                  style: const TextStyle(color: AppColors.teal, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _openScan(String barcode) async {
    final result = await Navigator.push<PriceComparison>(
      context,
      MaterialPageRoute(builder: (_) => _LoadingResultScreen(barcode: barcode)),
    );
    if (result != null) _loadRecent();
  }

  Widget _savingsTips() {
    final tips = [
      {'emoji': '🏪', 'store': 'Daraz.pk',  'discount': '15% OFF', 'category': 'Groceries',   'color': AppColors.teal},
      {'emoji': '🛒', 'store': 'Carrefour', 'discount': '20% OFF', 'category': 'Electronics', 'color': AppColors.amber},
    ];
    return Row(
      children: tips.asMap().entries.map((e) {
        final tip   = e.value;
        final color = tip['color'] as Color;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: e.key < tips.length - 1 ? 12 : 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(tip['emoji'] as String, style: const TextStyle(fontSize: 22)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(tip['discount'] as String, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(tip['store'] as String, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(tip['category'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── SCANNER SCREEN ───────────────────────────────────────────────────────────

class ScannerScreen extends StatefulWidget {
  final VoidCallback onHistoryTap;
  const ScannerScreen({super.key, required this.onHistoryTap});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scanCtrl;
  late Animation<double>   _scanAnim;
  bool _isLoading = false;
  String _loadingMsg = 'Fetching prices...';

  final _searchCtrl = TextEditingController();
  List<ProductInfo> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _simulateScan() async {
    // Pick a random demo barcode to simulate a real scan
    final barcode = _demoBarcodes[Random().nextInt(_demoBarcodes.length)];
    await _fetchAndNavigate(barcode);
  }

  Future<void> _fetchAndNavigate(String barcode) async {
    setState(() { _isLoading = true; _loadingMsg = 'Scanning barcode...'; });
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _loadingMsg = 'Fetching prices from stores...');

    try {
      final comparison = await ApiService.fetchPrices(barcode);
      await ApiService.saveScan(barcode);        // save to history
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ResultsScreen(data: comparison)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Could not reach the server. Make sure your backend is running.');
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() => _searchResults = []); return; }
    setState(() => _isSearching = true);
    try {
      final results = await ApiService.searchProducts(q.trim());
      if (mounted) setState(() { _searchResults = results; _isSearching = false; });
    } catch (_) {
      if (mounted) setState(() { _searchResults = []; _isSearching = false; });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Scan Product'), centerTitle: true, leading: const SizedBox()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _viewport(),
            const SizedBox(height: 24),
            _chips(),
            const SizedBox(height: 24),
            _scanButton(),
            const SizedBox(height: 12),
            _manualEntryButton(),
            const SizedBox(height: 28),
            _searchBar(),
            if (_isSearching) const Padding(padding: EdgeInsets.only(top: 16), child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2)),
            if (_searchResults.isNotEmpty) _searchResultsList(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _viewport() {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _isLoading ? AppColors.teal : AppColors.cardBorder, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0D1525), Color(0xFF0A0F1E)]))),
            CustomPaint(size: const Size(double.infinity, 260), painter: _GridPainter()),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: CustomPaint(painter: _CornerPainter(color: _isLoading ? AppColors.teal : AppColors.textMuted)),
              ),
            ),
            AnimatedBuilder(
              animation: _scanAnim,
              builder: (_, __) => Positioned(
                top: 40 + (_scanAnim.value * 180),
                left: 40, right: 40,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.teal.withOpacity(0), AppColors.teal, AppColors.teal.withOpacity(0)]),
                  ),
                ),
              ),
            ),
            if (!_isLoading)
              const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(height: 20),
                Icon(Icons.qr_code_2_rounded, color: Color(0x334A5568), size: 80),
                SizedBox(height: 12),
                Text('Point camera at barcode', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ])),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2.5),
                  const SizedBox(height: 16),
                  Text(_loadingMsg, style: const TextStyle(color: AppColors.teal, fontSize: 14, fontWeight: FontWeight.w600)),
                ])),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chips() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _chip(Icons.flash_on_rounded, 'Auto Flash'),
      const SizedBox(width: 12),
      _chip(Icons.crop_free_rounded, 'Auto Crop'),
      const SizedBox(width: 12),
      _chip(Icons.speed_rounded, 'Fast Detect'),
    ]);
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.teal, size: 14),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ]),
    );
  }

  Widget _scanButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _simulateScan,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.teal, AppColors.tealDark]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.teal.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
          SizedBox(width: 10),
          Text('Scan Barcode', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        ]),
      ),
    );
  }

  Widget _manualEntryButton() {
    return TextButton(
      onPressed: () => _showManualDialog(),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.keyboard_rounded, color: AppColors.textSecondary, size: 16),
        SizedBox(width: 6),
        Text('Enter barcode manually', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, decoration: TextDecoration.underline, decorationColor: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _searchBar() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Search by Product Name', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: AppColors.textPrimary),
        onChanged: _search,
        decoration: InputDecoration(
          hintText: 'e.g. Milo, Surf Excel...',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.teal)),
        ),
      ),
    ]);
  }

  Widget _searchResultsList() {
    return Column(
      children: _searchResults.map((p) {
        return GestureDetector(
          onTap: () => _fetchAndNavigate(p.barcode),
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
            child: Row(children: [
              Text(p.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${p.category} • ${p.barcode}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ]),
          ),
        );
      }).toList(),
    );
  }

  void _showManualDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Barcode', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. 8901030784232',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true, fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.teal)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (ctrl.text.trim().isNotEmpty) _fetchAndNavigate(ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Search', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── LOADING RESULT (used by Home recent-scans tap) ──────────────────────────

class _LoadingResultScreen extends StatefulWidget {
  final String barcode;
  const _LoadingResultScreen({required this.barcode});
  @override
  State<_LoadingResultScreen> createState() => _LoadingResultScreenState();
}

class _LoadingResultScreenState extends State<_LoadingResultScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.fetchPrices(widget.barcode);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultsScreen(data: data)));
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
    );
  }
}

// ─── RESULTS SCREEN ───────────────────────────────────────────────────────────

class ResultsScreen extends StatelessWidget {
  final PriceComparison data;
  const ResultsScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Price Comparison'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share_rounded, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _productHeader(),
          const SizedBox(height: 20),
          _cheapestBanner(),
          const SizedBox(height: 20),
          _priceRangeBar(),
          const SizedBox(height: 20),
          Row(children: [
            const Text('All Prices', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${data.storeCount} stores', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          ...data.prices.asMap().entries.map((e) => _priceCard(e.value, e.key == 0)),
          const SizedBox(height: 20),
          _actions(context),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _productHeader() {
    final p = data.product;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(p.emoji, style: const TextStyle(fontSize: 34))),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(children: [
            _badge(p.category, AppColors.blue),
            const SizedBox(width: 8),
            if (p.brand != null) _badge(p.brand!, AppColors.amber),
          ]),
          const SizedBox(height: 6),
          Text(p.barcode, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _cheapestBanner() {
    final c = data.cheapest;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.teal.withOpacity(0.2), AppColors.teal.withOpacity(0.04)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.teal.withOpacity(0.4)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.emoji_events_rounded, color: AppColors.amber, size: 18),
            SizedBox(width: 6),
            Text('BEST PRICE', style: TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ]),
          const SizedBox(height: 8),
          Text(c.storeName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(children: [
            _storeTypeBadge(c.storeType),
            const SizedBox(width: 8),
            _savingBadge('Save PKR ${data.difference.toStringAsFixed(0)}', AppColors.green),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('PKR', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(c.price.toStringAsFixed(0),
            style: const TextStyle(color: AppColors.teal, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
        ]),
      ]),
    );
  }

  Widget _priceRangeBar() {
    final fraction = data.minPrice / data.maxPrice;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Price Range', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text('PKR ${data.difference.toStringAsFixed(0)} diff', style: const TextStyle(color: AppColors.amber, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        Stack(children: [
          Container(height: 8, decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(4))),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.2, 1.0),
            child: Container(height: 8, decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.teal, AppColors.amber]),
              borderRadius: BorderRadius.circular(4),
            )),
          ),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('PKR ${data.minPrice.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.teal, fontSize: 14, fontWeight: FontWeight.w700)),
          Text('PKR ${data.maxPrice.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.red, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _priceCard(PriceEntry entry, bool isBest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isBest ? AppColors.teal.withOpacity(0.08) : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isBest ? AppColors.teal.withOpacity(0.5) : AppColors.cardBorder, width: isBest ? 1.5 : 1),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(entry.logoEmoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(entry.storeName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            if (isBest) _savingBadge('BEST', AppColors.amber),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _storeTypeBadge(entry.storeType),
            if (entry.rating != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.star_rounded, color: AppColors.amber, size: 14),
              const SizedBox(width: 2),
              Text(entry.rating!.toStringAsFixed(1), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('PKR ${entry.price.toStringAsFixed(0)}',
            style: TextStyle(color: isBest ? AppColors.teal : AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Icon(entry.inStock ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: entry.inStock ? AppColors.green : AppColors.red, size: 16),
        ]),
      ]),
    );
  }

  Widget _actions(BuildContext context) {
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.cardBorder),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.notifications_active_rounded, size: 18),
          label: const Text('Set Alert'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    ]);
  }

  // small helpers
  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11)),
  );

  Widget _storeTypeBadge(String type) {
    final isOnline = type == 'online';
    return _badge(isOnline ? '🌐 Online' : '🏪 Local', isOnline ? AppColors.blue : AppColors.teal);
  }

  Widget _savingBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

// ─── HISTORY SCREEN ───────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';

  final _filters = ['All', 'Beverages', 'Electronics', 'Household', 'Snacks'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await ApiService.fetchHistory();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load history. Is the server running?'; _loading = false; });
    }
  }

  Future<void> _delete(HistoryItem item) async {
    try {
      await ApiService.deleteHistoryItem(item.id);
      setState(() => _items.removeWhere((i) => i.id == item.id));
    } catch (_) {}
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All History?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text('This cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.clearHistory();
      setState(() => _items.clear());
    }
  }

  List<HistoryItem> get _filtered {
    if (_filter == 'All') return _items;
    return _items.where((i) => i.category.toLowerCase() == _filter.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Scan History'),
        centerTitle: true,
        leading: const SizedBox(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary), onPressed: _load),
          IconButton(icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.textSecondary), onPressed: _clearAll),
        ],
      ),
      body: Column(children: [
        if (_items.isNotEmpty) _summaryCard(),
        _filterChips(),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _summaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A2B40), Color(0xFF0F1D2E)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue.withOpacity(0.2)),
      ),
      child: Row(children: [
        _summaryItem(_items.length.toString(), 'Total Scans', AppColors.blue),
        _divider(),
        _summaryItem(_items.map((i) => i.storeCount).fold(0, (a, b) => a + b).toString(), 'Store Hits', AppColors.amber),
        _divider(),
        _summaryItem(_filtered.length.toString(), 'Filtered', AppColors.teal),
      ]),
    );
  }

  Widget _summaryItem(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(l, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
  ]));

  Widget _divider() => Container(width: 1, height: 32, color: AppColors.cardBorder);

  Widget _filterChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _filters[i];
          final active = f == _filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.teal : AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? AppColors.teal : AppColors.cardBorder),
              ),
              child: Text(f, style: TextStyle(color: active ? Colors.white : AppColors.textSecondary, fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
            ),
          );
        },
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2));
    if (_error != null) return _errorView();
    if (_filtered.isEmpty) return _emptyCard('No scans found.', '📭');
    return RefreshIndicator(
      color: AppColors.teal,
      backgroundColor: AppColors.card,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _historyCard(_filtered[i]),
      ),
    );
  }

  Widget _errorView() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⚠️', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ]),
    ));
  }

  Widget _historyCard(HistoryItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_rounded, color: AppColors.red),
      ),
      confirmDismiss: (_) async {
        await _delete(item);
        return true;
      },
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _LoadingResultScreen(barcode: item.barcode))),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.productName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                _catBadge(item.category),
                const SizedBox(width: 6),
                Text(_formatTime(item.scannedAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ]),
              const SizedBox(height: 6),
              Text('Best: PKR ${item.bestPrice.toStringAsFixed(0)} · ${item.storeCount} stores',
                style: const TextStyle(color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }

  Widget _catBadge(String cat) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: AppColors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
    child: Text(cat, style: const TextStyle(color: AppColors.blue, fontSize: 10)),
  );

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── NOTIFICATIONS SCREEN ─────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _priceDrops  = true;
  bool _weeklyReport = true;
  bool _flashDeals  = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        leading: const SizedBox(),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Mark all read', style: TextStyle(color: AppColors.teal, fontSize: 13)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _preferences(),
          const SizedBox(height: 24),
          const Text('Recent Alerts', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ..._staticNotifications.map(_notifCard),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _preferences() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.tune_rounded, color: AppColors.teal, size: 18),
          SizedBox(width: 8),
          Text('Alert Preferences', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        _toggle('📉', 'Price Drop Alerts', 'Notify when a saved product drops in price', _priceDrops,  (v) => setState(() => _priceDrops  = v)),
        _toggle('📊', 'Weekly Report',     'Get a summary of savings every week',          _weeklyReport, (v) => setState(() => _weeklyReport = v)),
        _toggle('⚡', 'Flash Deals',       'Limited-time offers on your scanned products', _flashDeals,   (v) => setState(() => _flashDeals  = v)),
      ]),
    );
  }

  Widget _toggle(String emoji, String title, String sub, bool val, ValueChanged<bool> cb) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(sub,   style: const TextStyle(color: AppColors.textMuted,    fontSize: 11)),
        ])),
        Switch.adaptive(value: val, onChanged: cb, activeColor: AppColors.teal, activeTrackColor: AppColors.teal.withOpacity(0.3), inactiveThumbColor: AppColors.textMuted, inactiveTrackColor: AppColors.bg),
      ]),
    );
  }

  Widget _notifCard(Map<String, dynamic> n) {
    final isNew = n['isNew'] as bool;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNew ? AppColors.card : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isNew ? AppColors.teal.withOpacity(0.3) : AppColors.cardBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(n['icon'] as String, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(n['title'] as String, style: TextStyle(color: isNew ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700))),
            if (isNew) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 4),
          Text(n['body'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
          const SizedBox(height: 6),
          Text(n['time'] as String, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
      ]),
    );
  }
}

// ─── SHARED HELPERS ───────────────────────────────────────────────────────────

Widget _emptyCard(String msg, String emoji) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
      ]),
    ),
  );
}

Widget _shimmerList(int count) {
  return Column(
    children: List.generate(count, (_) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 76,
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      );
    }),
  );
}

// ─── CUSTOM PAINTERS ──────────────────────────────────────────────────────────

class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 3..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    const l = 28.0;
    canvas.drawLine(Offset(0, l), Offset.zero, p);
    canvas.drawLine(Offset.zero, Offset(l, 0), p);
    canvas.drawLine(Offset(size.width - l, 0), Offset(size.width, 0), p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, l), p);
    canvas.drawLine(Offset(0, size.height - l), Offset(0, size.height), p);
    canvas.drawLine(Offset(0, size.height), Offset(l, size.height), p);
    canvas.drawLine(Offset(size.width - l, size.height), Offset(size.width, size.height), p);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - l), p);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.cardBorder.withOpacity(0.3)..strokeWidth = 0.5;
    const s = 28.0;
    for (double x = 0; x <= size.width;  x += s) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y <= size.height; y += s) canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
