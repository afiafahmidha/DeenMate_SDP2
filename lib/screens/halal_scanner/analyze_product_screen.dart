import 'package:flutter/material.dart';
import 'halal_scanner_home.dart';

class AnalyzeProductScreen extends StatefulWidget {
  final String? prefillType;

  const AnalyzeProductScreen({super.key, this.prefillType});

  @override
  State<AnalyzeProductScreen> createState() => _AnalyzeProductScreenState();
}

class _AnalyzeProductScreenState extends State<AnalyzeProductScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _explainController = TextEditingController();

  // Track attached photos (simulated)
  final List<bool> _frontPhotos = [false, false, false];
  final List<bool> _ingredientPhotos = [false, false, false];

  @override
  void initState() {
    super.initState();
    if (widget.prefillType != null) {
      _explainController.text = 'Attached photo via ${widget.prefillType}. Please analyze the ingredients.';
      // Pre-attach at least one photo
      _ingredientPhotos[0] = true;
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _emailController.dispose();
    _explainController.dispose();
    super.dispose();
  }

  void _submitAnalysis() {
    if (_barcodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a barcode number.')),
      );
      return;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    // Show beautiful success submitting dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF55A498)),
              SizedBox(width: 20),
              Text('Submitting analysis...'),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pop(context); // Pop loading

      // Show success alert
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Request Submitted'),
            ],
          ),
          content: const Text(
            'Thank you! Our expert food scientists will analyze your product and notify you once it\'s added to our database.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF55A498),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context); // Pop success
                Navigator.pop(context); // Return to home
              },
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      // Add dummy scanned item to history representing pending status
      HalalScannerState.addProduct(
        ScannedProduct(
          name: 'Under Review: Product (${_barcodeController.text})',
          barcode: _barcodeController.text,
          scanDate: DateTime.now(),
          status: 'MUSHBOOH',
          origin: 'pending analysis',
          risk: 'Under review',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: tealColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Analyze product',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _submitAnalysis,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barcode Input field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tealColor.withValues(alpha: 0.3)),
                ),
                child: TextField(
                  controller: _barcodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.qr_code_2_rounded, color: tealColor),
                    hintText: 'Barcode number...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Front product photos section
              const Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Front product photos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (index) {
                  return _buildPhotoPlaceholder(
                    isAttached: _frontPhotos[index],
                    onTap: () {
                      setState(() {
                        _frontPhotos[index] = !_frontPhotos[index];
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Ingredient photos section
              const Row(
                children: [
                  Icon(Icons.list_alt_rounded, color: Colors.grey, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Ingredient photos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (index) {
                  return _buildPhotoPlaceholder(
                    isAttached: _ingredientPhotos[index],
                    onTap: () {
                      setState(() {
                        _ingredientPhotos[index] = !_ingredientPhotos[index];
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 28),

              // User details section
              const Row(
                children: [
                  Icon(Icons.person_outline_rounded, color: Colors.grey, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Anything you would like to tell us?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: const TextStyle(color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: tealColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _explainController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Explain us here...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: tealColor),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPlaceholder({required bool isAttached, required VoidCallback onTap}) {
    const tealColor = Color(0xFF55A498);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 120,
        decoration: BoxDecoration(
          color: isAttached ? tealColor.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAttached ? tealColor : Colors.grey[300]!,
            width: isAttached ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: isAttached
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: tealColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Attached',
                      style: TextStyle(
                        color: tealColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              : Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.grey[400],
                  size: 32,
                ),
        ),
      ),
    );
  }
}
