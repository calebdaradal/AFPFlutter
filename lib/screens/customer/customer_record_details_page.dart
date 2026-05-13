import 'package:flutter/material.dart';

/// After a QR scan, shows customer details with a swipeable image carousel at the top.
class CustomerRecordDetailsPage extends StatelessWidget {
  const CustomerRecordDetailsPage({
    super.key,
    required this.customer,
    required this.record,
  });

  final Map<String, dynamic> customer;
  final Map<String, dynamic> record;

  String _asString(String key, {String fallback = '-'}) {
    final value = customer[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  /// Builds ordered unique URLs: vehicle images plus optional `imagePerson` from Mongo/API.
  List<String> _collectImageUrls() {
    final out = <String>[];
    void add(dynamic raw) {
      final s = raw?.toString().trim() ?? '';
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
    }
    add(customer['image']);
    add(customer['image_id']);
    add(customer['imageId']);
    add(customer['image_person']);
    add(customer['imagePerson']);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = _collectImageUrls();
    final fullName = '${_asString('first_name')} ${_asString('last_name')}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const SizedBox.shrink(),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topHalfHeight = constraints.maxHeight * 0.5;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: topHalfHeight,
                  child: _CustomerImageCarousel(imageUrls: imageUrls),
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.5,
                  minChildSize: 0.5,
                  maxChildSize: 0.92,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 48,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade500,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _InfoRow(label: 'Name', value: fullName),
                            _InfoRow(label: 'Address', value: _asString('address')),
                            _InfoRow(
                              label: 'Age',
                              value: customer['age']?.toString() ?? '-',
                            ),
                            _InfoRow(label: 'Car Model', value: _asString('car_model')),
                            _InfoRow(label: 'Car Make', value: _asString('car_make')),
                            _InfoRow(
                              label: 'Plate Number',
                              value: _asString('plate_number'),
                            ),
                            _InfoRow(
                              label: 'Vehicle Color',
                              value: _asString('vehicle_color'),
                            ),
                            _InfoRow(
                              label: 'Active',
                              value: (customer['active'] == true) ? 'Yes' : 'No',
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            _InfoRow(
                              label: 'Entry Type',
                              value: (record['type'] ?? '-').toString(),
                            ),
                            _InfoRow(
                              label: 'Date',
                              value: (record['date'] ?? '-').toString(),
                            ),
                            _InfoRow(
                              label: 'Time',
                              value: (record['time'] ?? '-').toString(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Swipeable full-width images with dot indicators when more than one URL is present.
class _CustomerImageCarousel extends StatefulWidget {
  const _CustomerImageCarousel({required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<_CustomerImageCarousel> createState() => _CustomerImageCarouselState();
}

class _CustomerImageCarouselState extends State<_CustomerImageCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _pageContent(int index) {
    final urls = widget.imageUrls;
    if (urls.isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, size: 48),
      );
    }
    final url = urls[index];
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, size: 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    final pageCount = urls.isEmpty ? 1 : urls.length;

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: pageCount,
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemBuilder: (context, index) => _pageContent(index),
        ),
        if (urls.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(urls.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: active ? Colors.white : Colors.white54,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
