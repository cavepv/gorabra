import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/activity_catalog.dart';
import '../services/recommender.dart';
import '../services/weather_lookup.dart';

/// Kid-interest tags present in the curated dataset.
const kidInterestTags = [
  'djur',
  'fordon',
  'friluftsliv',
  'historia',
  'konst',
  'lek',
  'lugn',
  'läsning',
  'musik',
  'natur',
  'skapande',
  'vatten',
  'vetenskap',
  'äventyr',
];

/// Parent-interest tags present in the curated dataset — things a parent
/// might want to introduce their kids to (scoring boost only, never a
/// hard filter, see design.md).
const parentInterestTags = [
  'fika',
  'historia',
  'konst',
  'kultur',
  'lugn',
  'läsning',
  'motion',
  'musik',
  'natur',
  'nostalgi',
  'sjöfart',
  'trädgård',
  'vetenskap',
];

/// Single screen: input form (5.1), spin/result display (5.2), re-spin
/// (5.3), and closest-matches labeling (5.4).
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

enum Day { today, tomorrow }

class _PlannerScreenState extends State<PlannerScreen> {
  List<Activity>? _catalog;
  WeatherForecast _forecast = const WeatherForecast();
  Day _selectedDay = Day.today;

  int _kidAge = 4;
  final Set<String> _selectedInterests = {};
  final Set<String> _selectedParentInterests = {};
  Cost _budget = Cost.medium;
  bool _hasCar = true;

  WeatherResult? get _selectedWeather =>
      _forecast.middayResult(_selectedDay == Day.today ? _forecast.today : _forecast.tomorrow);

  List<HourlyPoint> get _selectedHourly =>
      _selectedDay == Day.today ? _forecast.today : _forecast.tomorrow;

  RecommendationResult? _result;
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _loadWeather();
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await ActivityCatalog.load();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Kunde inte ladda aktiviteter. Försök igen.');
    }
  }

  Future<void> _loadWeather() async {
    // Fetched independently of the catalog so a slow/failed network call
    // never blocks the (instantly-available, bundled) catalog from
    // displaying — see weather-lookup spec's no-block-on-failure requirement.
    final forecast = await WeatherLookup.fetchForecast();
    if (!mounted) return;
    setState(() {
      _forecast = forecast;
      // If the user already spun while weather was still loading (or
      // absent), that result was computed without the weather filter tier
      // — clear it so a newly-arrived forecast doesn't sit next to a
      // stale recommendation it wasn't actually used for.
      _result = null;
    });
  }

  void _spin() {
    if (_catalog == null) return;
    setState(() {
      _loading = true;
      _result = null; // clear stale results while the new pick is computed
    });
    final prefs = UserPreferences(
      kidAge: _kidAge,
      kidInterests: _selectedInterests.toList(),
      parentInterests: _selectedParentInterests.toList(),
      budget: _budget,
      hasCar: _hasCar,
    );
    final result = ActivityRecommender().recommend(
      catalog: _catalog!,
      prefs: prefs,
      weather: _selectedWeather,
    );
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Görabra')),
      body: _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _loadCatalog,
                    child: const Text('Försök igen'),
                  ),
                ],
              ),
            )
          : _catalog == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildForm(),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : _spin,
                  icon: const Icon(Icons.casino),
                  label: Text(_result == null ? 'Spinna' : 'Spinna igen'),
                ),
                const SizedBox(height: 24),
                if (_result != null) _buildResults(_result!),
              ],
            ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<Day>(
          segments: const [
            ButtonSegment(value: Day.today, label: Text('Idag')),
            ButtonSegment(value: Day.tomorrow, label: Text('Imorgon')),
          ],
          selected: {_selectedDay},
          onSelectionChanged: (s) => setState(() {
            _selectedDay = s.first;
            _result = null;
          }),
        ),
        const SizedBox(height: 8),
        _buildWeatherSummary(),
        const SizedBox(height: 16),
        Text('Barnets ålder: $_kidAge', style: Theme.of(context).textTheme.titleMedium),
        Slider(
          value: _kidAge.toDouble(),
          min: 0,
          max: 12,
          divisions: 12,
          label: '$_kidAge',
          onChanged: (v) => setState(() {
            _kidAge = v.round();
            _result = null;
          }),
        ),
        const SizedBox(height: 8),
        Text('Barnets intressen', style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 8,
          children: kidInterestTags.map((tag) {
            final selected = _selectedInterests.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: selected,
              onSelected: (v) => setState(() {
                if (v) {
                  _selectedInterests.add(tag);
                } else {
                  _selectedInterests.remove(tag);
                }
                _result = null;
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          'Ditt intresse (bonus, filtrerar inte bort något)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Wrap(
          spacing: 8,
          children: parentInterestTags.map((tag) {
            final selected = _selectedParentInterests.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: selected,
              onSelected: (v) => setState(() {
                if (v) {
                  _selectedParentInterests.add(tag);
                } else {
                  _selectedParentInterests.remove(tag);
                }
                _result = null;
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text('Budget', style: Theme.of(context).textTheme.titleMedium),
        SegmentedButton<Cost>(
          segments: const [
            ButtonSegment(value: Cost.free, label: Text('Gratis')),
            ButtonSegment(value: Cost.low, label: Text('Låg')),
            ButtonSegment(value: Cost.medium, label: Text('Medel')),
            ButtonSegment(value: Cost.high, label: Text('Hög')),
          ],
          selected: {_budget},
          onSelectionChanged: (s) => setState(() {
            _budget = s.first;
            _result = null;
          }),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Har ni bil?'),
          value: _hasCar,
          onChanged: (v) => setState(() {
            _hasCar = v;
            _result = null;
          }),
        ),
      ],
    );
  }

  Widget _buildWeatherSummary() {
    final hourly = _selectedHourly;
    if (hourly.isEmpty) {
      return const Text('Väder ej tillgängligt just nu.');
    }
    final now = DateTime.now();
    // No fixed height: IntrinsicHeight lets the Row (and this scroll view)
    // size to its content, so larger text-scale settings grow the row
    // instead of overflowing a hard-coded box.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHourlyLegendColumn(),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final point in hourly)
                    _buildHourlyColumn(
                      point,
                      isCurrentHour:
                          _selectedDay == Day.today &&
                          point.time.year == now.year &&
                          point.time.month == now.month &&
                          point.time.day == now.day &&
                          point.time.hour == now.hour,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyColumn(HourlyPoint point, {required bool isCurrentHour}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: isCurrentHour
          ? BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Hour: small and muted so it reads as a label, not a value.
          Expanded(
            child: Center(
              child: Text(
                point.time.hour.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isCurrentHour
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isCurrentHour ? FontWeight.bold : null,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                iconForCondition(point.condition),
                size: 24,
                color: colorForCondition(point.condition),
              ),
            ),
          ),
          // Temp: bold and larger — the number people actually scan for.
          Expanded(
            child: Center(
              child: Text(
                '${point.temperatureC.round()}°',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fixed (non-scrolling) legend identifying what each row in the hourly
  /// strip means, so "08" / icon / "18°" reads unambiguously without
  /// needing to infer it from the scrolled-away header.
  ///
  /// Each marker is centered in an Expanded third of the shared row height
  /// (matching the three Expanded bands in each hourly column) rather than
  /// given a fixed pixel size, so the legend stays aligned with the hourly
  /// rows even when text-scale accessibility settings grow the hourly
  /// column's text but not these icons.
  Widget _buildHourlyLegendColumn() {
    final mutedStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(child: Center(child: Icon(Icons.schedule, size: 16, color: mutedStyle?.color))),
          const Expanded(
            child: Center(child: Icon(Icons.cloud_outlined, size: 24, color: Colors.transparent)),
          ),
          Expanded(
            child: Center(child: Icon(Icons.thermostat, size: 16, color: mutedStyle?.color)),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(RecommendationResult result) {
    if (result.activities.isEmpty) {
      return const Text('Inga aktiviteter matchar dina val just nu.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.isClosestMatch)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Chip(label: Text('Närmaste matchningar')),
          ),
        for (final activity in result.activities)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(activity.description),
                  const SizedBox(height: 8),
                  Text(
                    activity.benefitNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
