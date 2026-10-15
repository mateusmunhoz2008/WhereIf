import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/core/patterns/async_load_state.dart';
import 'package:autth_injustice_app/user_management/domain/models/user_directory_entry.dart';
import 'package:signals_flutter/signals_flutter.dart';

enum UserSortMode {
  nameAscending,
  nameDescending,
  hoursDescending,
  hoursAscending,
}

class UserManagementState with AsyncLoadState {
  final users = signal<List<UserDirectoryEntry>>(const []);
  final selectedRole = signal<AccountRole?>(null);
  final searchQuery = signal('');
  final sortMode = signal(UserSortMode.nameAscending);

  void reset() {
    users.value = const [];
    selectedRole.value = null;
    searchQuery.value = '';
    resetSort();
    loading.value = false;
    loaded.value = false;
    clearError();
  }

  bool get hasUsers => users.value.isNotEmpty;

  List<UserDirectoryEntry> get visibleUsers {
    final role = selectedRole.value;
    final query = searchQuery.value.trim().toLowerCase();
    final filtered = users.value.where((entry) {
      if (role != null && entry.account.role != role) return false;
      if (query.isEmpty) return true;

      return entry.name.toLowerCase().contains(query) ||
          entry.email.toLowerCase().contains(query);
    }).toList();

    switch (sortMode.value) {
      case UserSortMode.nameAscending:
        filtered.sort(_compareNames);
      case UserSortMode.nameDescending:
        filtered.sort((a, b) => _compareNames(b, a));
      case UserSortMode.hoursDescending:
        filtered.sort(
          (a, b) => b.totalComplementaryMinutes.compareTo(
            a.totalComplementaryMinutes,
          ),
        );
      case UserSortMode.hoursAscending:
        filtered.sort(
          (a, b) => a.totalComplementaryMinutes.compareTo(
            b.totalComplementaryMinutes,
          ),
        );
    }

    return List.unmodifiable(filtered);
  }

  static int _compareNames(
    UserDirectoryEntry a,
    UserDirectoryEntry b,
  ) {
    final aValue = a.name.trim().isEmpty ? a.email : a.name;
    final bValue = b.name.trim().isEmpty ? b.email : b.name;
    return aValue.toLowerCase().compareTo(bValue.toLowerCase());
  }

  void setUsers(List<UserDirectoryEntry> value) {
    users.value = List.unmodifiable(value);
    markLoaded();
  }

  void selectRole(AccountRole? value) => selectedRole.value = value;

  void setSearchQuery(String value) => searchQuery.value = value;

  void cycleSortMode() {
    sortMode.value = switch (sortMode.value) {
      UserSortMode.nameAscending => UserSortMode.nameDescending,
      UserSortMode.nameDescending => UserSortMode.hoursDescending,
      UserSortMode.hoursDescending => UserSortMode.hoursAscending,
      UserSortMode.hoursAscending => UserSortMode.nameAscending,
    };
  }

  void resetSort() => sortMode.value = UserSortMode.nameAscending;
}
