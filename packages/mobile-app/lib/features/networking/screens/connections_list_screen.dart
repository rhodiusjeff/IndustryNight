import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../widgets/connection_card.dart';

class ConnectionsListScreen extends StatelessWidget {
  const ConnectionsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Connections'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10, // TODO: Replace with actual data
        itemBuilder: (context, index) {
          return ConnectionCard(
            userId: 'user_$index',
            name: 'Connection ${index + 1}',
            specialty: 'Photographer',
            imageUrl: null,
            onTap: () => context.push('/users/user_$index'),
          );
        },
      ),
    );
  }
}
