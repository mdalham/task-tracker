import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/service/category/provider/category_provider.dart';
import '../../helper class/size_helper_class.dart';
import '../../models/dialog/delete_dialog.dart';
import '../../service/ads/banner/banner_ads.dart';
import '../../service/category/db/category_model.dart';
import '../../widget/custom_snack_bar.dart';

class CategoryBottomSheet extends StatefulWidget {
  final CategoryModel? editCategory;
  const CategoryBottomSheet({super.key, this.editCategory});

  @override
  State<CategoryBottomSheet> createState() => _CategoryBottomSheetState();
}

class _CategoryBottomSheetState extends State<CategoryBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  final bannerManager = SmartBannerManager(
    indices: [0,1,2],
    admobId: "ca-app-pub-7237142331361857/1563378585",
    metaId: "1916722012533263_1916773885861409",
    unityPlacementId: 'Banner_Android',
  );


  late TextEditingController _nameCtrl;
  CategoryModel? _editingCategory;

  @override
  void initState() {
    super.initState();
    bannerManager.loadAllBanners();

    _editingCategory = widget.editCategory;
    _nameCtrl = TextEditingController(text: _editingCategory?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    bannerManager.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final provider = Provider.of<CategoryProvider>(context, listen: false);

    try {
      if (_editingCategory == null) {
        // Add new category
        await provider.add(name);
        CustomSnackBar.show(
          context,
          message: 'Category added successfully!',
          type: SnackBarType.success,
        );
      } else {
        // Update existing category
        await provider.update(_editingCategory!.id!, name);
        CustomSnackBar.show(
          context,
          message: 'Category updated successfully!',
          type: SnackBarType.success,
        );
      }

      // Clear text field & reset editing state
      setState(() {
        _nameCtrl.clear();
        _editingCategory = null;
      });
    } catch (e) {
      CustomSnackBar.show(
        context,
        message: 'Failed to save category!',
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _delete(CategoryModel cat) async {
    final confirm = await deleteDialog(
      context: context,
      title: 'Delete Category?',
      message: 'Remove "${cat.name}" permanently?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirm != true) return;

    final provider = Provider.of<CategoryProvider>(context, listen: false);
    final deletedCat = cat;

    await provider.delete(cat.id!);

    if (!context.mounted) return;

    CustomSnackBar.show(
      context,
      message: 'Category deleted successfully!',
      type: SnackBarType.success,
      actionLabel: 'Undo',
      onAction: () async {
        await provider.add(deletedCat.name);
      },
    );

    // If we were editing the deleted category, reset text field
    if (_editingCategory?.id == cat.id) {
      setState(() {
        _editingCategory = null;
        _nameCtrl.clear();
      });
    }
  }

  void _edit(CategoryModel cat) {
    setState(() {
      _editingCategory = cat;
      _nameCtrl.text = cat.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CategoryProvider>(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final calendarIconWidth = SizeHelperClass.calendarDayWidth(context);
    final calendarIconHeight = SizeHelperClass.calendarDayHeight(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _editingCategory == null ? 'Add Category' : 'Edit Category',
                style: textTheme.displaySmall,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: bannerManager.bannerReady(0),
                builder: (_, isReady, __) {
                  if (!isReady) return const SizedBox.shrink();
                  return bannerManager.getBannerWidget(0);
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                style: textTheme.titleMedium,
                decoration: InputDecoration(
                  labelText: 'Category name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                ),
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF5B7FFF),
                ),
                onPressed: _save,
                child: Text(
                  _editingCategory == null ? 'Add' : 'Update',
                  style: textTheme.titleMedium!.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 30),
              Text('Categories', style: textTheme.titleLarge),
              ValueListenableBuilder<bool>(
                valueListenable: bannerManager.bannerReady(1),
                builder: (_, isReady, __) {
                  if (!isReady) return const SizedBox.shrink();
                  return bannerManager.getBannerWidget(1);
                },
              ),
              const SizedBox(height: 12),
              if (provider.categories.isEmpty)
                Center(
                  child: Text('No categories yet!', style: textTheme.bodyMedium),
                )
              else
                ...provider.categories.map(
                      (cat) => ListTile(
                    title: Text(cat.name, style: textTheme.titleMedium),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _edit(cat),
                          child: SvgPicture.asset(
                            'assets/icons/edit.svg',
                            width: calendarIconWidth + 3,
                            height: calendarIconHeight + 3,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurface,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _delete(cat),
                          child: SvgPicture.asset(
                            'assets/icons/trash.svg',
                            width: calendarIconWidth + 3,
                            height: calendarIconHeight + 3,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurface,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ValueListenableBuilder<bool>(
                valueListenable: bannerManager.bannerReady(2),
                builder: (_, isReady, __) {
                  if (!isReady) return const SizedBox.shrink();
                  return bannerManager.getBannerWidget(2);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
