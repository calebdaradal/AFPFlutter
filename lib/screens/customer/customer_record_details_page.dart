import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final imageUrl = _asString('image', fallback: '');
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
                  child: imageUrl.isEmpty
                      ? Container(
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported, size: 48),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade300,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, size: 48),
                          ),
                        ),
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
