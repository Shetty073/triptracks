import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/profile/providers/profile_provider.dart';
import 'package:frontend/core/auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _usernameController = TextEditingController();
  final _foodExpenseController = TextEditingController();
  final _stayExpenseController = TextEditingController();
  String _distanceUnit = 'km';
  String _currency = 'USD';
  String _themeMode = 'system';
  String _accentColor = 'deepPurple';

  @override
  void dispose() {
    _usernameController.dispose();
    _foodExpenseController.dispose();
    _stayExpenseController.dispose();
    super.dispose();
  }

  void _saveSettings(UserProfileSettings currentSettings) {
    if (_usernameController.text.isNotEmpty) {
      ref
          .read(profileNotifierProvider)
          .updateProfile(_usernameController.text.trim());
    }

    final newSettings = UserProfileSettings(
      distanceUnit: _distanceUnit,
      currency: _currency,
      themeMode: _themeMode,
      accentColor: _accentColor,
      avgDailyFoodExpense:
          double.tryParse(_foodExpenseController.text) ??
          currentSettings.avgDailyFoodExpense,
      avgNightlyStayExpense:
          double.tryParse(_stayExpenseController.text) ??
          currentSettings.avgNightlyStayExpense,
      vehicles: currentSettings.vehicles,
    );
    ref.read(profileNotifierProvider).updateSettings(newSettings);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings Saved!')));
  }

  void _showAddVehicleDialog() {
    String type = 'car';
    final nameController = TextEditingController();
    final seatsController = TextEditingController();
    final mileageController = TextEditingController();
    final avgDistController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Vehicle'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'car', child: Text('Car')),
                    DropdownMenuItem(
                      value: 'motorcycle',
                      child: Text('Motorcycle'),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      type = val!;
                      if (type == 'motorcycle') seatsController.text = '2';
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Vehicle Type'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Name (Optional)',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: seatsController,
                  decoration: const InputDecoration(labelText: 'Seats'),
                  keyboardType: TextInputType.number,
                  enabled: type != 'motorcycle',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: mileageController,
                  decoration: const InputDecoration(
                    labelText: 'Mileage (per unit/liter)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: avgDistController,
                  decoration: const InputDecoration(labelText: 'Avg Dist/Day'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(profileNotifierProvider).addVehicle({
                'name': nameController.text.isNotEmpty
                    ? nameController.text
                    : null,
                'type': type,
                'seats': int.tryParse(seatsController.text) ?? 4,
                'mileage_per_liter':
                    double.tryParse(mileageController.text) ?? 15.0,
                'avg_distance_per_day':
                    double.tryParse(avgDistController.text) ?? 500.0,
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(profileSettingsProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile Setup')),
      body: settingsAsync.when(
        data: (settings) {
          // Initialize controllers on first load if empty
          if (_foodExpenseController.text.isEmpty && user != null) {
            _usernameController.text = user.username;
            _foodExpenseController.text = settings.avgDailyFoodExpense
                .toString();
            _stayExpenseController.text = settings.avgNightlyStayExpense
                .toString();
            _distanceUnit = settings.distanceUnit;
            _currency = settings.currency;
            _themeMode = settings.themeMode;
            _accentColor = settings.accentColor;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Personal Info',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Preferences',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _distanceUnit,
                items: const [
                  DropdownMenuItem(value: 'km', child: Text('Kilometers')),
                  DropdownMenuItem(value: 'miles', child: Text('Miles')),
                ],
                onChanged: (val) => setState(() => _distanceUnit = val!),
                decoration: const InputDecoration(labelText: 'Distance Unit'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                items: const [
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                  DropdownMenuItem(value: 'INR', child: Text('INR')),
                ],
                onChanged: (val) => setState(() => _currency = val!),
                decoration: const InputDecoration(labelText: 'Currency'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _themeMode,
                items: const [
                  DropdownMenuItem(
                    value: 'system',
                    child: Text('System Default'),
                  ),
                  DropdownMenuItem(value: 'light', child: Text('Light Mode')),
                  DropdownMenuItem(value: 'dark', child: Text('Dark Mode')),
                ],
                onChanged: (val) => setState(() => _themeMode = val!),
                decoration: const InputDecoration(labelText: 'Theme Mode'),
              ),
              const SizedBox(height: 16),
              const Text('Accent Color', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildColorOption('deepPurple', Colors.deepPurple),
                  _buildColorOption('blue', Colors.blue),
                  _buildColorOption('green', Colors.green),
                  _buildColorOption('orange', Colors.orange),
                  _buildColorOption('red', Colors.red),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _foodExpenseController,
                decoration: const InputDecoration(
                  labelText: 'Avg Daily Food Expense',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _stayExpenseController,
                decoration: const InputDecoration(
                  labelText: 'Avg Nightly Stay Expense',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _saveSettings(settings),
                child: const Text('Save Preferences'),
              ),
              const Divider(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vehicles',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: Colors.deepPurple,
                    ),
                    onPressed: _showAddVehicleDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...settings.vehicles.map(
                (v) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      v['type'] == 'motorcycle'
                          ? Icons.motorcycle
                          : Icons.directions_car,
                    ),
                    title: Text(
                      v['name'] != null
                          ? '${v['name']} (${v['type'].toString().toUpperCase()})'
                          : '${v['type'].toString().toUpperCase()} - ${v['seats']} Seats',
                    ),
                    subtitle: Text(
                      'Mileage: ${v['mileage_per_liter']} | Avg/Day: ${v['avg_distance_per_day']}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => ref
                          .read(profileNotifierProvider)
                          .removeVehicle(v['id']),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildColorOption(String colorName, Color color) {
    final isSelected = _accentColor == colorName;
    return GestureDetector(
      onTap: () => setState(() => _accentColor = colorName),
      child: CircleAvatar(
        backgroundColor: color,
        radius: isSelected ? 20 : 16,
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
