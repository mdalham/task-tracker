import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class MultiImageGrid extends StatefulWidget {
  final List<File> images;
  final Function(int) onImageTap;
  final Function(int) onRemove;

  const MultiImageGrid({
    super.key,
    required this.images,
    required this.onImageTap,
    required this.onRemove,
  });

  @override
  State<MultiImageGrid> createState() => _MultiImageGridState();
}

class _MultiImageGridState extends State<MultiImageGrid> {
  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemCount: widget.images.length,
      itemBuilder: (context, index) {
        final file = widget.images[index];
        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () => widget.onImageTap(index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: () => widget.onRemove(index), // <-- fixed
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
