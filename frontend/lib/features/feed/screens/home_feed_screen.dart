import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/auth_provider.dart';
import 'package:frontend/features/profile/screens/profile_setup_screen.dart';
import 'package:frontend/features/feed/providers/feed_provider.dart';
import 'package:frontend/shared/widgets/trip_card.dart';
import 'package:frontend/features/trips/screens/my_trips_screen.dart';
import 'package:frontend/features/crew/screens/crew_screen.dart';
import 'package:frontend/features/trip_details/screens/trip_details_screen.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  int _currentIndex = 0;

  // Dynamic screen resolution in build to allow rebuild with Providers if needed
  // Alternatively we can just build the widget tree directly in the body based on index

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const _PublicFeedWidget(), // Feed
      const MyTripsScreen(), // My Trips
      const CrewScreen(), // Crew Screen
      const ProfileSetupScreen(), // Profile screen
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('TripTracks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.commute), label: 'My Trips'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Crew'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _PublicFeedWidget extends ConsumerStatefulWidget {
  const _PublicFeedWidget();

  @override
  ConsumerState<_PublicFeedWidget> createState() => _PublicFeedWidgetState();
}

class _PublicFeedWidgetState extends ConsumerState<_PublicFeedWidget> {
  late final TextEditingController searchController;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(
      text: ref.read(feedSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(publicFeedProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search trips or destinations...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  searchController.clear();
                  ref.read(feedSearchQueryProvider.notifier).updateQuery('');
                },
              ),
            ),
            onSubmitted: (value) {
              ref.read(feedSearchQueryProvider.notifier).updateQuery(value);
            },
          ),
        ),
        Expanded(
          child: feedAsync.when(
            data: (trips) {
              if (trips.isEmpty) {
                return const Center(
                  child: Text("No public trips found. Plan one today!"),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.refresh(publicFeedProvider),
                child: ListView.builder(
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    return TripCard(
                      trip: trips[index],
                      onViewMore: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) =>
                                TripDetailsScreen(tripId: trips[index].id),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text("Error loading feed: $err")),
          ),
        ),
      ],
    );
  }
}
