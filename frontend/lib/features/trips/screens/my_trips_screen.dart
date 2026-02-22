import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/trips/providers/trips_provider.dart';
import 'package:frontend/shared/widgets/trip_card.dart';
import 'package:frontend/models/trip.dart';
import 'package:frontend/features/trip_details/screens/trip_details_screen.dart';
import 'package:frontend/features/plan_trip/screens/plan_trip_screen.dart';

class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(myTripsProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: const TabBar(
          isScrollable: true,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          tabs: [
            Tab(text: "Planned (Me)"),
            Tab(text: "Completed (Me)"),
            Tab(text: "Active (Participant)"),
            Tab(text: "Completed (Participant)"),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const PlanTripScreen()),
            );
          },
          icon: const Icon(Icons.add_road),
          label: const Text('Plan a Trip'),
        ),
        body: tripsAsync.when(
          data: (categories) {
            return TabBarView(
              children: [
                _TripList(
                  trips: categories.plannedByMe,
                  label: "You haven't planned any trips yet",
                ),
                _TripList(
                  trips: categories.completedByMe,
                  label: "You have no completed trips",
                ),
                _TripList(
                  trips: categories.participantActive,
                  label: "You are not participating in active trips",
                ),
                _TripList(
                  trips: categories.participantCompleted,
                  label: "No completed trips as participant",
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text("Error loading trips: $err")),
        ),
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  final List<Trip> trips;
  final String label;

  const _TripList({required this.trips, required this.label});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mode_of_travel, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: trips.length,
      itemBuilder: (context, index) {
        return TripCard(
          trip: trips[index],
          onViewMore: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => TripDetailsScreen(tripId: trips[index].id),
              ),
            );
          },
        );
      },
    );
  }
}
