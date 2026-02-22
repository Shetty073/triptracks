import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/plan_trip/providers/plan_trip_provider.dart';

class PlanTripScreen extends ConsumerStatefulWidget {
  const PlanTripScreen({super.key});

  @override
  ConsumerState<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends ConsumerState<PlanTripScreen> {
  final _titleController = TextEditingController();

  LocationSuggestion? _source;
  LocationSuggestion? _destination;
  final List<LocationSuggestion> _stops = [];

  Map<String, dynamic>? _itineraryData;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _addLocation(
    String label,
    ValueChanged<LocationSuggestion> onSelected,
  ) async {
    final result = await showSearch<LocationSuggestion?>(
      context: context,
      delegate: _LocationSearchDelegate(ref),
    );
    if (result != null) {
      onSelected(result);
    }
  }

  Future<void> _calculatePlan() async {
    if (_source == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source and Destination are required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final intel = await ref
          .read(planTripProvider)
          .calculateItinerary(
            source: _source!,
            destination: _destination!,
            stops: _stops,
          );
      setState(() => _itineraryData = intel);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_titleController.text.isEmpty ||
        _source == null ||
        _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title, Source and Destination are required'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(planTripProvider)
          .saveTripDraft(
            title: _titleController.text,
            source: _source!,
            destination: _destination!,
            stops: _stops,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft saved!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan a Trip')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Trip Title (e.g. Summer Road Trip)',
                  ),
                ),
                const SizedBox(height: 16),

                // Map locations
                ListTile(
                  title: Text(_source?.name ?? 'Select Source'),
                  leading: const Icon(Icons.my_location, color: Colors.green),
                  trailing: const Icon(Icons.search),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => _addLocation(
                    'Source',
                    (loc) => setState(() => _source = loc),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(_destination?.name ?? 'Select Destination'),
                  leading: const Icon(Icons.flag, color: Colors.blue),
                  trailing: const Icon(Icons.search),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => _addLocation(
                    'Destination',
                    (loc) => setState(() => _destination = loc),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Stops (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_location_alt,
                        color: Colors.deepPurple,
                      ),
                      onPressed: () => _addLocation(
                        'Stop',
                        (loc) => setState(() => _stops.add(loc)),
                      ),
                    ),
                  ],
                ),
                ..._stops.asMap().entries.map(
                  (e) => ListTile(
                    title: Text(e.value.name),
                    leading: CircleAvatar(
                      radius: 12,
                      child: Text('${e.key + 1}'),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => setState(() => _stops.removeAt(e.key)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.insights),
                  label: const Text('Calculate Route Intelligence'),
                  onPressed: _calculatePlan,
                ),

                if (_itineraryData != null) ...[
                  const SizedBox(height: 24),
                  Card(
                    color: Colors.deepPurple.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trip Intelligence',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Distance: ${_itineraryData!['total_distance_km']} km',
                          ),
                          Text(
                            'Estimated Drive Time: ${(_itineraryData!['total_estimated_time_mins'] / 60).toStringAsFixed(1)} hours',
                          ),
                          Text(
                            'Estimated Days (Based on your capability): ${_itineraryData!['estimated_days']} days',
                          ),
                          if ((_itineraryData!['suggestions'] as List)
                              .isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              '⚠️ Smart Suggestions:',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ...(_itineraryData!['suggestions'] as List).map(
                              (s) => Text('- ${s['segment']}: ${s['reason']}'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveDraft,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Save as Planned Trip'),
                ),
              ],
            ),
    );
  }
}

class _LocationSearchDelegate extends SearchDelegate<LocationSuggestion?> {
  final WidgetRef ref;
  _LocationSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions(context);

  Widget _buildSuggestions(BuildContext context) {
    if (query.isEmpty)
      return const Center(child: Text('Type to search locations'));

    return FutureBuilder<List<LocationSuggestion>>(
      future: ref.read(planTripProvider).fetchAutocomplete(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snapshot.data ?? [];
        if (results.isEmpty) return const Center(child: Text('No results'));

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: const Icon(Icons.location_city),
              title: Text(results[index].name),
              onTap: () => close(context, results[index]),
            );
          },
        );
      },
    );
  }
}
