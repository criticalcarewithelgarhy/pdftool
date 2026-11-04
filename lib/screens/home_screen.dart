import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../widgets/feature_card.dart';
import 'encrypt_screen.dart';
import 'decrypt_screen.dart';
import 'merge_screen.dart';
import 'split_screen.dart';
import 'info_screen.dart';
import 'batch_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    final features = [
      _Feature(
        icon: Icons.lock_outline,
        label: 'Encrypt',
        description: 'Add password protection',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EncryptScreen()),
        ),
      ),
      _Feature(
        icon: Icons.lock_open,
        label: 'Decrypt',
        description: 'Remove password protection',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DecryptScreen()),
        ),
      ),
      _Feature(
        icon: Icons.merge_type,
        label: 'Merge',
        description: 'Combine multiple PDFs',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MergeScreen()),
        ),
      ),
      _Feature(
        icon: Icons.call_split,
        label: 'Split',
        description: 'Extract pages by range',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SplitScreen()),
        ),
      ),
      _Feature(
        icon: Icons.info_outline,
        label: 'PDF Info',
        description: 'View metadata & stats',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InfoScreen()),
        ),
      ),
      _Feature(
        icon: Icons.lock,
        label: 'Batch Encrypt',
        description: 'Protect many files at once',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BatchScreen(mode: BatchMode.encrypt)),
        ),
      ),
      _Feature(
        icon: Icons.lock_open_outlined,
        label: 'Batch Decrypt',
        description: 'Unlock many files at once',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BatchScreen(mode: BatchMode.decrypt)),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf, size: 24),
            SizedBox(width: 8),
            Text('PDF Toolkit'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 480 ? 3 : 2;
            return GridView.builder(
              itemCount: features.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                final f = features[index];
                return FeatureCard(
                  icon: f.icon,
                  label: f.label,
                  description: f.description,
                  onTap: f.onTap,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  _Feature({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });
}
