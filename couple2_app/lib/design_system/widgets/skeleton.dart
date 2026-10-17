import 'package:flutter/material.dart';

import 'shimmer.dart';

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          for (var i = 0; i < rows; i++) ...[
            const Row(
              children: [
                SkeletonBox(height: 44, width: 44, radius: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 14, width: 180),
                      SizedBox(height: 8),
                      SkeletonBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key, this.lines = 3, this.minHeight});

  final int lines;

  /// Matches the loaded card so the list does not jump when data arrives.
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Shimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 14, width: 140),
                for (var i = 0; i < lines; i++) ...[
                  const SizedBox(height: 12),
                  SkeletonBox(height: 12, width: i == lines - 1 ? 160 : null),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FormSkeleton extends StatelessWidget {
  const FormSkeleton({super.key, this.fields = 4});

  final int fields;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < fields; i++) ...[
            const SkeletonBox(height: 18, width: 120),
            const SizedBox(height: 8),
            const SkeletonBox(height: 48, radius: 16),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
