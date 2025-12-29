import 'package:flutter/material.dart';
import 'package:tasktracker/helper%20class/size_helper_class.dart';



class EmptyState extends StatefulWidget {
  final String title;
  const EmptyState({super.key, required this.title});

  @override
  State<EmptyState> createState() => _EmptyStateState();
}


class _EmptyStateState extends State<EmptyState> {

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      height: SizeHelperClass.homeConSHeight(context),
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.onPrimaryContainer,
        border: Border.all(color: colorScheme.outline),
      ),
      child:  Text(widget.title, style: textTheme.bodyMedium),
    );
  }
}
