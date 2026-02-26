import 'package:flutter/material.dart';

class PostsListScreen extends StatelessWidget {
  const PostsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Moderation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search posts...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      hint: const Text('Filter'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Posts')),
                        DropdownMenuItem(value: 'reported', child: Text('Reported')),
                        DropdownMenuItem(value: 'hidden', child: Text('Hidden')),
                      ],
                      onChanged: (value) {},
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: CircleAvatar(child: Text('U${index + 1}')),
                      title: Text('Post content preview for post ${index + 1}...'),
                      subtitle: Text('By User ${index + 1} • ${index + 1}h ago'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (index % 3 == 0)
                            const Chip(
                              label: Text('Reported'),
                              backgroundColor: Colors.orange,
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.visibility_off),
                            tooltip: 'Hide',
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () {},
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
