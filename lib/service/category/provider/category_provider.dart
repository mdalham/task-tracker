import 'package:tasktracker/service/category/db/category_db_helper.dart';
import 'package:flutter/material.dart';
import '../db/category_model.dart';

class CategoryProvider with ChangeNotifier {
  final List<CategoryModel> _categories = [];
  final CategoryDbHelper _db = CategoryDbHelper();

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;
  List<CategoryModel> get categories => List.unmodifiable(_categories);

  final List<CategoryModel> _defaultCategories = [
    CategoryModel(name: 'Work', ),
    CategoryModel(name: 'Personal',),
    CategoryModel(name: 'Ideas',),
  ];

  Future<void> loadCategories() async {
    final dbList = await _db.fetchAll();
    _categories.clear();

    if (dbList.isEmpty) {
      // Insert default categories
      for (final cat in _defaultCategories) {
        final id = await _db.insert(cat);
        _categories.add(cat.copyWith(id: id));
      }
    } else {
      _categories.addAll(dbList);
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> add(String name) async {
    final model = CategoryModel(name: name,);
    final id = await _db.insert(model);
    _categories.add(model.copyWith(id: id));
    notifyListeners();
  }

  Future<void> update(int id, String newName) async {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final updated = _categories[index].copyWith(name: newName);
    await _db.update(updated);
    _categories[index] = updated;
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await _db.delete(id);
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}
