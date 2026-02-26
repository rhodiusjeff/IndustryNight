import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/specialty_chip.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final List<String> _selectedSpecialties = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search people...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      body: Column(
        children: [
          // Specialty filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: Specialty.all.take(6).map((specialty) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SpecialtyChip(
                    specialty: specialty.name,
                    selected: _selectedSpecialties.contains(specialty.id),
                    onTap: () {
                      setState(() {
                        if (_selectedSpecialties.contains(specialty.id)) {
                          _selectedSpecialties.remove(specialty.id);
                        } else {
                          _selectedSpecialties.add(specialty.id);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(),

          // Results
          Expanded(
            child: _searchController.text.isEmpty && _selectedSpecialties.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Search for people',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: 10, // TODO: Replace with actual results
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceLight,
                          child: Text(getInitials('User ${index + 1}')),
                        ),
                        title: Text('User ${index + 1}'),
                        subtitle: const Text('Photographer'),
                        onTap: () => context.push('/users/user_$index'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
