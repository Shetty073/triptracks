import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/debouncer.dart';
import 'package:frontend/features/plan_trip/providers/plan_trip_provider.dart';

// ─── Main Screen ─────────────────────────────────────────────────────────────

class PlanTripScreen extends ConsumerStatefulWidget {
  const PlanTripScreen({super.key});

  @override
  ConsumerState<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends ConsumerState<PlanTripScreen> {
  // ── Trip details ──
  final _titleCtrl = TextEditingController();
  LocationSuggestion? _source;
  LocationSuggestion? _destination;
  final List<LocationSuggestion> _stops = [];

  // ── Crew & vehicle ──
  List<CrewMemberForTrip> _crewList = [];
  bool _crewLoaded = false;
  final Set<String> _selectedCrewIds = {};
  final Map<String, String?> _selectedVehicle = {};   // userId → vehicleId
  final Map<String, String> _roles = {};               // userId → 'driver'|'passenger'
  final Set<String> _selectedVehicleIds = {};          // vehicles added to this trip
  // all vehicles from crew (indexed by id)
  final Map<String, VehicleOption> _allVehiclesById = {};

  // ── Fuel price ──
  final _fuelPriceCtrl = TextEditingController(text: '100');

  // ── Calculated results (editable) ──
  Map<String, dynamic>? _plan;
  final _distCtrl      = TextEditingController();
  final _timeCtrl      = TextEditingController();
  final _daysCtrl      = TextEditingController();
  final _stayCostCtrl  = TextEditingController();
  final _foodCostCtrl  = TextEditingController();
  final _fuelCostCtrl  = TextEditingController();
  final _totalCostCtrl = TextEditingController();
  // Per-vehicle fuel cost controllers: vehicleId → ctrl
  final Map<String, TextEditingController> _vehicleFuelCtrls = {};

  bool _isLoading = false;
  bool _isSaving  = false;

  @override
  void initState() {
    super.initState();
    _loadCrew();
    // Whenever any cost field changes, recompute total
    for (final ctrl in [_stayCostCtrl, _foodCostCtrl, _fuelCostCtrl]) {
      ctrl.addListener(_recomputeTotal);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _fuelPriceCtrl, _distCtrl, _timeCtrl, _daysCtrl,
      _stayCostCtrl, _foodCostCtrl, _fuelCostCtrl, _totalCostCtrl,
    ]) {
      c.dispose();
    }
    for (final c in _vehicleFuelCtrls.values) { c.dispose(); }
    super.dispose();
  }

  // ── Reactive total ──────────────────────────────────────────────────────────
  void _recomputeTotal() {
    final stay  = double.tryParse(_stayCostCtrl.text) ?? 0;
    final food  = double.tryParse(_foodCostCtrl.text) ?? 0;
    // Sum all per-vehicle fuel costs (if present), else use aggregate ctrl
    double fuel = 0;
    if (_vehicleFuelCtrls.isNotEmpty) {
      for (final c in _vehicleFuelCtrls.values) {
        fuel += double.tryParse(c.text) ?? 0;
      }
      // Keep aggregate in sync
      _fuelCostCtrl.removeListener(_recomputeTotal);
      _fuelCostCtrl.text = fuel.toStringAsFixed(2);
      _fuelCostCtrl.addListener(_recomputeTotal);
    } else {
      fuel = double.tryParse(_fuelCostCtrl.text) ?? 0;
    }
    _totalCostCtrl.text = (stay + food + fuel).toStringAsFixed(2);
  }

  void _recomputeTotalFromVehicle() {
    // Called when a per-vehicle controller changes
    double fuel = 0;
    for (final c in _vehicleFuelCtrls.values) {
      fuel += double.tryParse(c.text) ?? 0;
    }
    _fuelCostCtrl.removeListener(_recomputeTotal);
    _fuelCostCtrl.text = fuel.toStringAsFixed(2);
    _fuelCostCtrl.addListener(_recomputeTotal);
    _recomputeTotal();
  }

  // ── Crew loading ────────────────────────────────────────────────────────────
  Future<void> _loadCrew() async {
    try {
      final crew = await ref.read(planTripProvider).fetchCrewWithVehicles();
      final Map<String, VehicleOption> byId = {};
      for (final m in crew) {
        for (final v in m.vehicles) { byId[v.id] = v; }
      }
      if (mounted) {
        debugPrint('Loaded crew: ${crew.length} members');
        for (final m in crew) {
          debugPrint(' - ${m.displayName} (id: ${m.id}) Vehicles: ${m.vehicles.length}');
        }
        setState(() {
          _crewList = crew;
          _allVehiclesById.clear();
          _allVehiclesById.addAll(byId);
          _crewLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _crewLoaded = true);
    }
  }

  // ── Location search ─────────────────────────────────────────────────────────
  Future<void> _pickLocation(ValueChanged<LocationSuggestion> onPicked) async {
    final result = await showSearch<LocationSuggestion?>(
      context: context,
      delegate: _LocationSearchDelegate(ref),
    );
    if (result != null) setState(() => onPicked(result));
  }

  // ── Calculate ───────────────────────────────────────────────────────────────
  Future<void> _calculate() async {
    if (_source == null || _destination == null) {
      _showSnack('Source and Destination are required');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final fuelPrice = double.tryParse(_fuelPriceCtrl.text) ?? 100.0;
      final selectedVehicles = _selectedVehicleIds
          .where(_allVehiclesById.containsKey)
          .map((id) => _allVehiclesById[id]!)
          .toList();

      final data = await ref.read(planTripProvider).calculateItinerary(
        source: _source!,
        destination: _destination!,
        stops: _stops,
        selectedVehicles: selectedVehicles,
        fuelPricePerLiter: fuelPrice,
      );

      // Prefill all editable controllers
      _distCtrl.text    = (data['total_distance_km'] as num).toStringAsFixed(1);
      _timeCtrl.text    = ((data['total_estimated_time_mins'] as num) / 60).toStringAsFixed(1);
      _daysCtrl.text    = data['estimated_days'].toString();
      _stayCostCtrl.text = (data['estimated_stay_cost'] as num? ?? 0).toStringAsFixed(2);
      _foodCostCtrl.text = (data['estimated_food_cost'] as num? ?? 0).toStringAsFixed(2);
      _fuelCostCtrl.text = (data['estimated_fuel_cost'] as num? ?? 0).toStringAsFixed(2);
      _totalCostCtrl.text = (data['total_estimated_cost'] as num? ?? 0).toStringAsFixed(2);

      // Per-vehicle fuel controllers
      for (final c in _vehicleFuelCtrls.values) { c.dispose(); }
      _vehicleFuelCtrls.clear();
      final vehicleCosts = data['vehicle_fuel_costs'] as List? ?? [];
      for (final vc in vehicleCosts) {
        final ctrl = TextEditingController(
          text: (vc['fuel_cost'] as num).toStringAsFixed(2),
        );
        ctrl.addListener(_recomputeTotalFromVehicle);
        _vehicleFuelCtrls[vc['vehicle_id'] as String] = ctrl;
      }

      setState(() => _plan = data);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty || _source == null || _destination == null) {
      _showSnack('Title, Source and Destination are required');
      return;
    }
    final participants = _selectedCrewIds.map((uid) => TripParticipantAssignment(
      userId: uid,
      role: _roles[uid] ?? 'passenger',
      vehicleId: _selectedVehicle[uid],
    )).toList();

    setState(() => _isSaving = true);
    try {
      await ref.read(planTripProvider).saveTripDraft(
        title: _titleCtrl.text.trim(),
        source: _source!,
        destination: _destination!,
        stops: _stops,
        participants: participants,
        totalDistanceKm: double.tryParse(_distCtrl.text),
        totalTimeMins: ((double.tryParse(_timeCtrl.text) ?? 0) * 60).round(),
      );
      if (!mounted) return;
      _showSnack('Trip saved!');
      Navigator.pop(context);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String? _driverForVehicle(String vehicleId) {
    for (final uid in _selectedCrewIds) {
      if (_selectedVehicle[uid] == vehicleId && _roles[uid] == 'driver') return uid;
    }
    return null;
  }

  int _getOccupancy(String vehicleId, {String? excludeUserId}) {
    int count = 0;
    for (final uid in _selectedCrewIds) {
      if (uid == excludeUserId) continue;
      if (_selectedVehicle[uid] == vehicleId) count++;
    }
    return count;
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Plan a Trip')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 1. Trip Title ────────────────────────────────────────
                _header('Trip Details', Icons.edit_road, primary),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Trip Title',
                    hintText: 'e.g. Thane → Udupi Road Trip',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 2. Locations ─────────────────────────────────────────
                _locTile(Icons.my_location, Colors.green,
                    _source?.name ?? 'Select Source',
                    () => _pickLocation((l) => _source = l)),
                const SizedBox(height: 8),
                _locTile(Icons.flag, Colors.blue,
                    _destination?.name ?? 'Select Destination',
                    () => _pickLocation((l) => _destination = l)),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Stops (Optional)',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.add_location_alt, color: primary),
                      onPressed: () => _pickLocation((l) => _stops.add(l)),
                    ),
                  ],
                ),
                ..._stops.asMap().entries.map((e) => ListTile(
                  dense: true,
                  title: Text(e.value.name),
                  leading: CircleAvatar(radius: 12, child: Text('${e.key + 1}')),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                    onPressed: () => setState(() => _stops.removeAt(e.key)),
                  ),
                )),

                // ── 3. Crew & Vehicles (before calculate) ─────────────────
                const SizedBox(height: 20),
                _header('Crew & Vehicles', Icons.people_outline, primary),
                const SizedBox(height: 4),
                Text('Select who is joining and which vehicles are used.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 10),

                if (!_crewLoaded)
                  const Center(child: CircularProgressIndicator())
                else if (_crewList.isEmpty)
                  _infoBox('No crew members yet. Add friends from the Crew tab.')
                else
                  ..._crewList.map((m) => _crewCard(m, primary)),

                // ── Fuel Price ────────────────────────────────────────────
                const SizedBox(height: 16),
                _header('Fuel Price', Icons.local_gas_station_outlined, primary),
                const SizedBox(height: 8),
                _numField(_fuelPriceCtrl, 'Fuel Price per Litre (₹)', Icons.local_gas_station_outlined),

                // ── 4. Calculate ──────────────────────────────────────────
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.insights),
                  label: const Text('Calculate Route Intelligence'),
                  onPressed: _calculate,
                ),

                // ── 5. Route Results ──────────────────────────────────────
                if (_plan != null) ...[
                  const SizedBox(height: 24),
                  _header('Route Intelligence', Icons.analytics_outlined, primary),
                  Text('Pre-filled — adjust as needed.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(child: _numField(_distCtrl, 'Distance (km)', Icons.straighten)),
                    const SizedBox(width: 12),
                    Expanded(child: _numField(_timeCtrl, 'Drive Time (hrs)', Icons.timer_outlined)),
                  ]),
                  const SizedBox(height: 12),
                  _numField(_daysCtrl, 'Estimated Days', Icons.calendar_today_outlined),

                  // Leg breakdown
                  if ((_plan!['legs'] as List).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ExpansionTile(
                      title: const Text('Leg Breakdown',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      leading: const Icon(Icons.route),
                      children: (_plan!['legs'] as List).asMap().entries.map((e) {
                        final leg = e.value as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(children: [
                            Expanded(child: Text('Leg ${e.key + 1}',
                                style: const TextStyle(fontWeight: FontWeight.w500))),
                            Text(
                              '${(leg['distance_km'] as num).toStringAsFixed(1)} km  •  '
                              '${((leg['estimated_time_mins'] as num) / 60).toStringAsFixed(1)} hrs',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
                  ],

                  // Suggestions
                  if ((_plan!['suggestions'] as List).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Row(children: [
                          Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                          SizedBox(width: 6),
                          Text('Smart Suggestions',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        ]),
                        ...(_plan!['suggestions'] as List).map((s) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('• ${s['segment']}: ${s['reason']}',
                              style: const TextStyle(fontSize: 13)),
                        )),
                      ]),
                    ),
                  ],

                  // ── 6. Cost Breakdown ──────────────────────────────────
                  const SizedBox(height: 24),
                  _header('Cost Estimates', Icons.account_balance_wallet_outlined, Colors.green),
                  Text('All values editable — total updates automatically.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 12),

                  _numField(_stayCostCtrl, 'Estimated Stay Cost (₹)', Icons.hotel_outlined),
                  const SizedBox(height: 12),
                  _numField(_foodCostCtrl, 'Estimated Food Cost (₹)', Icons.restaurant_outlined),
                  const SizedBox(height: 12),

                  // Per-vehicle fuel
                  if (_vehicleFuelCtrls.isNotEmpty) ...[
                    Text('Fuel Cost per Vehicle',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...(_plan!['vehicle_fuel_costs'] as List? ?? []).map((vc) {
                      final vid = vc['vehicle_id'] as String;
                      final vName = vc['vehicle_name'] as String;
                      final ctrl = _vehicleFuelCtrls[vid];
                      if (ctrl == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _numField(ctrl, '$vName Fuel (₹)',
                            Icons.directions_car_outlined),
                      );
                    }),
                  ] else ...[
                    _numField(_fuelCostCtrl, 'Estimated Fuel Cost (₹)',
                        Icons.local_gas_station_outlined),
                  ],

                  const SizedBox(height: 16),
                  // Total — highlighted
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.savings_outlined, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _totalCostCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                          decoration: const InputDecoration(
                            labelText: 'Total Estimated Cost (₹)',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],

                // ── 7. Save ───────────────────────────────────────────────
                const SizedBox(height: 32),
                _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save as Planned Trip'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: _save,
                      ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // ── Crew card ───────────────────────────────────────────────────────────────

  Widget _crewCard(CrewMemberForTrip member, Color primary) {
    final isSelected = _selectedCrewIds.contains(member.id);
    final selectedVehicleId = _selectedVehicle[member.id];
    final currentRole = _roles[member.id] ?? 'passenger';
    final driverOfVehicle = selectedVehicleId != null
        ? _driverForVehicle(selectedVehicleId) : null;
    final canBeDriver = driverOfVehicle == null || driverOfVehicle == member.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        CheckboxListTile(
          value: isSelected,
          activeColor: primary,
          title: Text(member.isMe ? '${member.displayName} (Me)' : member.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(member.email, style: const TextStyle(fontSize: 12)),
          secondary: CircleAvatar(
            backgroundColor: primary.withValues(alpha: 0.15),
            child: Text(member.displayName[0].toUpperCase(),
                style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
          ),
          onChanged: (val) => setState(() {
            if (val == true) {
              _selectedCrewIds.add(member.id);
              _roles[member.id] = 'passenger';
            } else {
              _selectedCrewIds.remove(member.id);
              _selectedVehicle.remove(member.id);
              _roles.remove(member.id);
            }
          }),
        ),

        if (isSelected) Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Vehicle picker
            if (_allVehiclesById.isEmpty)
              Row(children: [
                Icon(Icons.directions_car_outlined,
                    size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text('No vehicles registered by any member',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ])
            else
              DropdownButtonFormField<String>(
                key: ValueKey(member.id + (selectedVehicleId ?? '_none')),
                initialValue: selectedVehicleId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Vehicle',
                  isDense: true,
                  prefixIcon: Icon(Icons.directions_car_outlined, size: 20),
                ),
                hint: const Text('Select vehicle'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No vehicle')),
                  ..._allVehiclesById.values.map((v) {
                    final occ = _getOccupancy(v.id, excludeUserId: member.id);
                    final isFull = occ >= v.seats;
                    // Find owner name for this vehicle
                    final owner = _crewList.firstWhere(
                      (m) => m.vehicles.any((vv) => vv.id == v.id),
                      orElse: () => member,
                    );
                    final ownerLabel = owner.id == member.id ? 'You' : owner.displayName;

                    return DropdownMenuItem(
                      value: isFull ? null : v.id,
                      enabled: !isFull,
                      child: Text(
                        '${v.name} ($ownerLabel) • $occ/${v.seats} seats',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isFull ? Colors.grey : null,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }),
                ],
                onChanged: (vid) => setState(() {
                  _selectedVehicle[member.id] = vid;
                  if (vid != null) _selectedVehicleIds.add(vid);
                }),
              ),

            const SizedBox(height: 10),

            // Role chips
            Row(children: [
              const Text('Role:',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(width: 10),
              _roleChip('Driver', Icons.airline_seat_recline_normal,
                  currentRole == 'driver', canBeDriver,
                  canBeDriver ? () => setState(() => _roles[member.id] = 'driver') : null),
              const SizedBox(width: 8),
              _roleChip('Passenger', Icons.person_outline,
                  currentRole == 'passenger', true,
                  () => setState(() => _roles[member.id] = 'passenger')),
            ]),
            if (!canBeDriver)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Driver already assigned for this vehicle.',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
              ),
          ]),
        ),
      ]),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _header(String title, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
    ]),
  );

  Widget _locTile(IconData icon, Color color, String label, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
            const Icon(Icons.search, color: Colors.grey, size: 20),
          ]),
        ),
      );

  Widget _numField(TextEditingController ctrl, String label, IconData icon) =>
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: Icon(icon, size: 18),
        ),
      );

  Widget _infoBox(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      Icon(Icons.info_outline, color: Colors.grey.shade600),
      const SizedBox(width: 8),
      Expanded(child: Text(msg)),
    ]),
  );

  Widget _roleChip(String label, IconData icon, bool selected, bool enabled,
      VoidCallback? onTap) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = selected ? (enabled ? primary : Colors.grey) : Colors.grey.shade200;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14,
              color: selected ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: selected ? Colors.white : Colors.grey.shade700,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}

// ── Location Search Delegate ─────────────────────────────────────────────────

class _LocationSearchDelegate extends SearchDelegate<LocationSuggestion?> {
  final WidgetRef ref;
  final _debouncer = Debouncer();
  final _debouncedQuery = ValueNotifier<String>('');

  _LocationSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () {
      query = '';
      _debouncedQuery.value = '';
    }),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    _debouncedQuery.value = query;
    return _buildBody();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _debouncer.run(() => _debouncedQuery.value = query);
    return _buildBody();
  }

  Widget _buildBody() => ValueListenableBuilder<String>(
    valueListenable: _debouncedQuery,
    builder: (ctx, q, _) {
      if (q.isEmpty) return const Center(child: Text('Type to search locations'));
      return FutureBuilder<List<LocationSuggestion>>(
        future: ref.read(planTripProvider).fetchAutocomplete(q),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final results = snap.data ?? [];
          if (results.isEmpty) return const Center(child: Text('No results found'));
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (ctx, i) => ListTile(
              leading: const Icon(Icons.location_city),
              title: Text(results[i].name),
              onTap: () => close(ctx, results[i]),
            ),
          );
        },
      );
    },
  );
}
