import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:afpflutter/services/api_config.dart'; // added: for base URL

/// After a QR scan, shows passcard owner + vehicle details in a draggable modal.
class CustomerRecordDetailsPage extends StatefulWidget {
  const CustomerRecordDetailsPage({
    super.key,
    required this.owner,
    required this.vehicle,
    required this.passcard,
    required this.record,
    required this.passcardStatus,
  });

  final Map<String, dynamic> owner;
  final Map<String, dynamic> vehicle;
  final Map<String, dynamic> passcard;
  final Map<String, dynamic> record;
  final String passcardStatus;

  @override
  State<CustomerRecordDetailsPage> createState() => _CustomerRecordDetailsPageState();
}

class _CustomerRecordDetailsPageState extends State<CustomerRecordDetailsPage> {
  @override
  void initState() {
    super.initState();
  }

  String _asStringFrom(Map<String, dynamic> source, String key, {String fallback = '-'}) {
    final value = source[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  List<String> _collectVehicleImageUrls(Map<String, dynamic> vehicle) {
    final out = <String>[];
    void add(dynamic raw) {
      final s = raw?.toString().trim() ?? '';
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
    }

    // Helper to build full URL from proxy path
    String fullUrl(String path) {
      if (path.isEmpty) return '';
      if (path.startsWith('http')) return path; // already full URL
      return '${ApiConfig.baseUrl}/$path';
    }

    // d_car image (vehicle) - FIRST
    final dCarProxy = vehicle['d_car_image_proxy_path'];
    if (dCarProxy != null) add(fullUrl(dCarProxy.toString()));
    else {
      final dCarDirect = vehicle['d_car_image_url'];
      if (dCarDirect != null) add(fullUrl(dCarDirect.toString()));
    }

    // d_owner image (owner) - SECOND
    final dOwnerProxy = vehicle['d_owner_image_proxy_path'];
    if (dOwnerProxy != null) add(fullUrl(dOwnerProxy.toString()));
    else {
      final dOwnerDirect = vehicle['d_owner_image_url'];
      if (dOwnerDirect != null) add(fullUrl(dOwnerDirect.toString()));
    }

    // d_or image (OR) - THIRD
    final dOrProxy = vehicle['d_or_image_proxy_path'];
    if (dOrProxy != null) add(fullUrl(dOrProxy.toString()));
    else {
      final dOrDirect = vehicle['d_or_image_url'];
      if (dOrDirect != null) add(fullUrl(dOrDirect.toString()));
    }

    // Vehicle fallback (only if no d_car)
    final vehicleProxy = vehicle['image_proxy_path'];
    if (vehicleProxy != null) add(fullUrl(vehicleProxy.toString()));
    else {
      final vehicleDirect = vehicle['image_url'];
      if (vehicleDirect != null) add(fullUrl(vehicleDirect.toString()));
    }

    return out;
  }

  Color _statusValueColor(String value, {required Set<String> goodValues}) { // added: map statuses to green/red based on allowlist
    final text = value.trim().toUpperCase(); // added: normalize value
    if (text.isEmpty || text == '-') return Colors.grey.shade700; // added: neutral for missing
    if (goodValues.contains(text)) return const Color(0xFF2E7D32); // added: green for good statuses
    return const Color(0xFFC62828); // added: red for anything else
  } // added: end color mapper

  Widget _statusBadge(String value, {required Set<String> goodValues}) { // added: pill badge for status values
    final text = value.trim().isEmpty ? '-' : value.trim().toUpperCase(); // added: normalize display text
    final color = _statusValueColor(text, goodValues: goodValues); // added: compute badge color
    return Container( // added: badge container
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // added: badge padding
      decoration: BoxDecoration( // added: badge style
        color: color.withOpacity(0.12), // added: soft background
        borderRadius: BorderRadius.circular(999), // added: pill shape
        border: Border.all(color: color.withOpacity(0.35)), // added: subtle border
      ), // added: end decoration
      child: Text( // added: badge text
        text, // added: status text
        style: TextStyle( // added: badge text style
          fontWeight: FontWeight.w700, // added: bold
          color: color, // added: color follows status
          letterSpacing: 0.8, // added: spaced letters
        ), // added: end style
      ), // added: end text
    ); // added: end container
  } // added: end badge

  Widget _statusBadgeColumn({required String label, required String value, required Set<String> goodValues, bool alignRight = true}) { // changed: allow left/right alignment
    return Column( // added: stack label above badge
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start, // changed: anchor based on alignRight
      children: [ // added: children
        Text( // added: label text
          label, // added: label
          style: TextStyle( // added: label style
            fontSize: 12, // added: label size
            color: Colors.grey.shade600, // added: label color
            fontWeight: FontWeight.w700, // added: stronger label
          ), // added: end style
        ), // added: end label
        const SizedBox(height: 6), // added: spacing
        _statusBadge(value, goodValues: goodValues), // added: badge value
      ], // added: end children
    ); // added: end column
  } // added: end badge column

  String _ownerFullName(Map<String, dynamic> owner) {
    final first = _asStringFrom(owner, 'first_name', fallback: '').trim();
    final middle = _asStringFrom(owner, 'middle_name', fallback: '').trim();
    final last = _asStringFrom(owner, 'last_name', fallback: '').trim();
    final parts = [first, middle, last].where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? '-' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.owner;
    final ownerStatus = _asStringFrom(owner, 'status');
    final passcardStatus = (widget.passcardStatus).toString().trim();
    final vehicle = widget.vehicle;
    final vehicleStatus = _asStringFrom(vehicle, 'status');
    final passcard = widget.passcard;
    final imageUrls = _collectVehicleImageUrls(vehicle); // added: vehicle image carousel URLs

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const SizedBox.shrink(),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topHeight = constraints.maxHeight * 0.38;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: topHeight,
                  child: _VehicleImageCarousel(imageUrls: imageUrls), // changed: show vehicle image at top (presigned URL)
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.62,
                  minChildSize: 0.62,
                  maxChildSize: 0.94,
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
                            const SizedBox(height: 16),
                            Padding( // changed: status layout (owner/vehicle left; passcard right)
                              padding: const EdgeInsets.only(bottom: 14), // changed: spacing
                              child: Row( // changed: left column + right passcard
                                crossAxisAlignment: CrossAxisAlignment.start, // changed: align tops
                                children: [ // changed: children
                                  Expanded( // changed: occupy left side
                                    child: Column( // changed: stack owner then vehicle on the left
                                      crossAxisAlignment: CrossAxisAlignment.start, // changed: anchor left
                                      children: [ // changed: left column children
                                        _statusBadgeColumn( // changed: owner status left
                                          label: 'Owner', // changed: label
                                          value: ownerStatus, // changed: value
                                          goodValues: const {'ACTIVE'}, // changed: green only when ACTIVE
                                          alignRight: false, // changed: anchor left
                                        ), // changed: end owner
                                        const SizedBox(height: 16), // changed: spacing between owner and vehicle
                                        _statusBadgeColumn( // changed: vehicle status left
                                          label: 'Vehicle', // changed: label
                                          value: vehicleStatus, // changed: value
                                          goodValues: const {'ACTIVE'}, // changed: green only when ACTIVE
                                          alignRight: false, // changed: anchor left
                                        ), // changed: end vehicle
                                      ], // changed: end children
                                    ), // changed: end column
                                  ), // changed: end expanded
                                  const SizedBox(width: 14), // changed: spacing between columns
                                  Align( // changed: keep passcard block anchored right while left-aligning its label
                                    alignment: Alignment.topRight, // changed: anchor the whole block to the right
                                    child: _statusBadgeColumn( // changed: passcard status on the right
                                      label: 'Passcard', // changed: label
                                      value: passcardStatus, // changed: value
                                      goodValues: const {'APPROVED'}, // changed: green only when APPROVED
                                      alignRight: false, // changed: left-align label + badge within the block
                                    ), // changed: end passcard column
                                  ), // changed: end align
                                ], // changed: end children
                              ), // changed: end row
                            ), // changed: end status row
                            _InfoRow(label: 'Rank', value: _asStringFrom(owner, 'rank_name')),
                            _InfoRow(label: 'Name', value: _ownerFullName(owner)),
                            _InfoRow(label: 'MobileNo', value: _asStringFrom(owner, 'mobile_no')),
                            _InfoRow(label: 'Address', value: _asStringFrom(owner, 'address')),
                            _InfoRow(label: 'Category', value: _asStringFrom(passcard, 'category')),
                            _InfoRow(label: 'CategoryEligibility', value: _asStringFrom(passcard, 'category_eligibility')),
                            _InfoRow(label: 'CategorySpecification', value: _asStringFrom(passcard, 'category_specification')),
                            const SizedBox(height: 10),
                            const Divider(),
                            const SizedBox(height: 10),
                            const Text(
                              'Vehicle',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(label: 'PlateNumber', value: _asStringFrom(vehicle, 'plate_number')),
                            _InfoRow(label: 'Model', value: _asStringFrom(vehicle, 'model')),
                            _InfoRow(label: 'Color', value: _asStringFrom(vehicle, 'color')),
                            _InfoRow(label: 'YearModel', value: _asStringFrom(vehicle, 'year_model')),
                            _InfoRow(
                              label: 'WheelType Description',
                              value: _asStringFrom(vehicle, 'wheel_type_description'),
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

class _VehicleImageCarousel extends StatefulWidget { // added: swipeable carousel for vehicle images (single image for now)
  const _VehicleImageCarousel({required this.imageUrls}); // added: constructor

  final List<String> imageUrls; // added: list of URLs

  @override
  State<_VehicleImageCarousel> createState() => _VehicleImageCarouselState(); // added: create state
} // added: end widget

class _VehicleImageCarouselState extends State<_VehicleImageCarousel> { // added: state for carousel
  late final PageController _pageController; // added: controller for PageView
  int _currentPage = 0; // added: current page index

  void _openImageViewer(String url) { // added: open full-screen zoomable image
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageViewerPage(url: url),
      ),
    );
  }

  @override
  void initState() { // added: init controller
    super.initState(); // added: call base
    _pageController = PageController(); // added: create controller
  } // added: end initState

  @override
  void dispose() { // added: dispose controller
    _pageController.dispose(); // added: dispose controller
    super.dispose(); // added: call base dispose
  } // added: end dispose

  Widget _pageContent(int index) { // added: render each page (image)
    final urls = widget.imageUrls; // added: local ref
    if (urls.isEmpty) { // added: placeholder when no URL
      return Container( // added: placeholder container
        color: Colors.grey.shade200, // added: background
        alignment: Alignment.center, // added: center icon
        child: Icon(Icons.directions_car, size: 84, color: Colors.grey.shade600), // added: placeholder icon
      ); // added: end container
    } // added: end empty case
    final url = urls[index]; // added: url for this page
    return GestureDetector(
      onTap: () => _openImageViewer(url),
      child: Image.network( // added: load image from URL
        url, // added: image url
        fit: BoxFit.cover, // added: cover mode
        width: double.infinity, // added: fill width
        height: double.infinity, // added: fill height
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final expected = loadingProgress.expectedTotalBytes;
          final loaded = loadingProgress.cumulativeBytesLoaded;
          final value = (expected != null && expected > 0) ? (loaded / expected) : null;
          return Container(
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(value: value),
            ),
          );
        },
        errorBuilder: (_, error, __) {
          if (kDebugMode) {
            debugPrint('Image load failed: $error');
            debugPrint('Image URL: $url');
          }
          return Container(
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: Icon(Icons.broken_image, size: 84, color: Colors.grey.shade600),
          );
        },
      ), // added: end Image.network
    );
  } // added: end page content

  @override
  Widget build(BuildContext context) { // added: build carousel
    final urls = widget.imageUrls; // added: local ref
    final pageCount = urls.isEmpty ? 1 : urls.length; // added: at least 1 page for placeholder
    return Stack( // added: stack for dots overlay
      fit: StackFit.expand, // added: fill
      children: [ // added: children
        PageView.builder( // added: swipable pages
          controller: _pageController, // added: controller
          itemCount: pageCount, // added: number of pages
          onPageChanged: (i) => setState(() => _currentPage = i), // added: track page index
          itemBuilder: (context, index) => _pageContent(index), // added: page builder
        ), // added: end PageView
        if (urls.length > 1) // added: show dots only when multiple images exist
          Positioned( // added: position dots at bottom
            left: 0, // added: stretch
            right: 0, // added: stretch
            bottom: 12, // added: offset
            child: Row( // added: dot row
              mainAxisAlignment: MainAxisAlignment.center, // added: centered
              children: List.generate(urls.length, (i) { // added: generate dots
                final active = i == _currentPage; // added: active dot
                return AnimatedContainer( // added: animated dot width
                  duration: const Duration(milliseconds: 200), // added: animation duration
                  margin: const EdgeInsets.symmetric(horizontal: 4), // added: spacing
                  width: active ? 22 : 8, // added: active wider
                  height: 8, // added: dot height
                  decoration: BoxDecoration( // added: dot style
                    borderRadius: BorderRadius.circular(4), // added: rounded
                    color: active ? Colors.white : Colors.white54, // added: color
                  ), // added: end decoration
                ); // added: end container
              }), // added: end dots
            ), // added: end row
          ), // added: end positioned
      ], // added: end children
    ); // added: end stack
  } // added: end build
} // added: end state

class _ImageViewerPage extends StatelessWidget {
  const _ImageViewerPage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                final expected = loadingProgress.expectedTotalBytes;
                final loaded = loadingProgress.cumulativeBytesLoaded;
                final value = (expected != null && expected > 0) ? (loaded / expected) : null;
                return SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    value: value,
                    color: Colors.white,
                  ),
                );
              },
              errorBuilder: (_, error, __) {
                if (kDebugMode) {
                  debugPrint('Image load failed: $error');
                  debugPrint('Image URL: $url');
                }
                return Icon(Icons.broken_image, size: 84, color: Colors.white54);
              },
            ),
          ),
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
