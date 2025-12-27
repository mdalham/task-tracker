import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/helper%20class/icon_helper.dart';
import 'package:tasktracker/helper%20class/size_helper_class.dart';
import '../../service/notification/provider/notification_provider.dart';
import '../dialog/confirm_dialog.dart';
import '../../widget/custom_snack_bar.dart';


class ClearHistory extends StatelessWidget {
  const ClearHistory({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: SvgPicture.asset(
        IconHelper.trash,
        width: SizeHelperClass.calendarDayWidth(context) + 3,
        height: SizeHelperClass.calendarDayHeight(context) + 3,
        colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      ),
      tooltip: 'Clear History',
      onPressed: () async {
        final provider = context.read<NotificationProvider>();

        final confirm = await showConfirmDialog(
          context: context,
          title: "Clear All Notifications?",
          message: "This action cannot be undone.",
          confirmText: "Clear All",
          confirmColor: Colors.red,
        );


        if (!context.mounted) return;
        if (confirm != true) return;

        await provider.deleteAll();

        if (!context.mounted) return;
        CustomSnackBar.show(
          context,
          message: 'History cleared',
          type: SnackBarType.success,
        );
      },
    );
  }
}
