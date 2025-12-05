import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vote_app_thesis/models/user.dart';
import 'package:vote_app_thesis/models/enums.dart';
import 'package:vote_app_thesis/services/app_state_service.dart';
import 'package:vote_app_thesis/services/server_service.dart';
import 'package:vote_app_thesis/widgets/user_list_item.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<HiveUser> _users = [];
  List<HiveUser> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;
  bool _isAddingUser = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // In a real implementation, you would fetch users from your backend
      // For now, using placeholder data
      final users = <HiveUser>[
        HiveUser(
          id: '1',
          username: 'admin',
          email: 'admin@voteapp.com',
          role: UserRole.admin,
          isActive: true,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
        HiveUser(
          id: '2',
          username: 'user1',
          email: 'user1@example.com',
          role: UserRole.participant,
          isActive: true,
          createdAt: DateTime.now().subtract(const Duration(days: 15)),
        ),
        HiveUser(
          id: '3',
          username: 'user2',
          email: 'user2@example.com',
          role: UserRole.participant,
          isActive: false,
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
      ];

      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users
            .where(
              (user) =>
                  user.username.toLowerCase().contains(query) ||
                  user.email.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  Future<void> _addUser() async {
    if (_usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isAddingUser = true;
    });

    try {
      // In a real implementation, you would add the user via your backend
      final newUser = HiveUser(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        role: UserRole.participant,
        isActive: true,
        createdAt: DateTime.now(),
      );

      setState(() {
        _users.add(newUser);
        _filteredUsers = _users;
        _isAddingUser = false;
      });

      _usernameController.clear();
      _emailController.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User added successfully')));
    } catch (e) {
      setState(() {
        _isAddingUser = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add user: $e')));
    }
  }

  Future<void> _toggleUserStatus(HiveUser user) async {
    try {
      // In a real implementation, you would update the user via your backend
      final updatedUser = user.copyWith(isActive: !user.isActive);

      setState(() {
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          _users[index] = updatedUser;
          _filterUsers(); // Update filtered list
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User ${updatedUser.isActive ? 'activated' : 'deactivated'}',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update user: $e')));
    }
  }

  Future<void> _deleteUser(HiveUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete user "${user.username}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // In a real implementation, you would delete the user via your backend
      setState(() {
        _users.removeWhere((u) => u.id == user.id);
        _filterUsers(); // Update filtered list
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete user: $e')));
    }
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _usernameController.clear();
              _emailController.clear();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isAddingUser ? null : _addUser,
            child: _isAddingUser
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add User'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Add User Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search users...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showAddUserDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add User'),
                ),
              ],
            ),
          ),

          // User List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error: $_error',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadUsers,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No users found'
                              : 'No users available',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return UserListItem(
                        user: user,
                        onToggleStatus: () => _toggleUserStatus(user),
                        onDelete: () => _deleteUser(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
