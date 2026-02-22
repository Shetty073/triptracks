import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/crew/providers/crew_provider.dart';

class CrewScreen extends ConsumerStatefulWidget {
  const CrewScreen({super.key});

  @override
  ConsumerState<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends ConsumerState<CrewScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Crew')),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.deepPurple,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.deepPurple,
              tabs: [
                Tab(text: 'My Crew'),
                Tab(text: 'Requests'),
                Tab(text: 'Search'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _MyCrewList(),
                  _PendingRequestsList(),
                  _SearchCrew(
                    controller: _searchController,
                    query: _searchQuery,
                    onSearch: (q) => setState(() => _searchQuery = q),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyCrewList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crewAsync = ref.watch(myCrewProvider);
    return crewAsync.when(
      data: (crew) {
        if (crew.isEmpty)
          return const Center(
            child: Text('No crew members yet. Search to add friends!'),
          );
        return ListView.builder(
          itemCount: crew.length,
          itemBuilder: (context, index) {
            final user = crew[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user.username),
              subtitle: Text(user.email),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _PendingRequestsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqsAsync = ref.watch(pendingRequestsProvider);
    return reqsAsync.when(
      data: (reqs) {
        if (reqs.isEmpty)
          return const Center(child: Text('No pending requests'));
        return ListView.builder(
          itemCount: reqs.length,
          itemBuilder: (context, index) {
            final req = reqs[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_add)),
              title: Text(
                'Request from User ID: ${req.senderId}',
              ), // Real app would join with user table to show name
              trailing: ElevatedButton(
                onPressed: () =>
                    ref.read(crewNotifierProvider).acceptRequest(req.id),
                child: const Text('Accept'),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _SearchCrew extends ConsumerWidget {
  final TextEditingController controller;
  final String query;
  final Function(String) onSearch;

  const _SearchCrew({
    required this.controller,
    required this.query,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAsync = ref.watch(searchCrewProvider(query));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Search username or email',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => onSearch(controller.text),
              ),
            ),
            onSubmitted: onSearch,
          ),
        ),
        Expanded(
          child: searchAsync.when(
            data: (results) {
              if (results.isEmpty && query.isNotEmpty) {
                return const Center(child: Text('No users found'));
              }
              return ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final user = results[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(user.username),
                    subtitle: Text(user.email),
                    trailing: OutlinedButton(
                      child: const Text('Add'),
                      onPressed: () async {
                        try {
                          await ref
                              .read(crewNotifierProvider)
                              .sendRequest(user.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Request Sent!')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}
