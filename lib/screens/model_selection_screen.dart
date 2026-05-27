import 'package:flutter/material.dart';

import 'brand_selection_screen.dart';

/// Returns the badge colour for an engine type.
///
/// Still used by widgets that display the selected vehicle's engine type.
Color engineTypeColor(String engineType) {
  switch (engineType) {
    case 'diesel':
      return Colors.grey;
    case 'hybrid':
      return Colors.green;
    case 'electric':
      return Colors.blue;
    case 'gasoline':
    default:
      return Colors.amber;
  }
}

/// Deprecated: the brand → model → year flow is now handled entirely by the
/// single-screen [BrandSelectionScreen]. This widget is kept only so any
/// lingering navigation target still resolves; it immediately redirects.
@Deprecated('Vehicle selection is now handled by BrandSelectionScreen.')
class ModelSelectionScreen extends StatelessWidget {
  const ModelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) => const BrandSelectionScreen();
}
