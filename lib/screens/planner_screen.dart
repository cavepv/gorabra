import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/activity_catalog.dart';
import '../services/location_lookup.dart';
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
  /// Injectable position fetcher — defaults to real GPS via
  /// [LocationLookup], overridable in tests (mirrors the `Random? random`
  /// seam already used in [ActivityRecommender]).
  final Future<UserPosition?> Function() positionFetcher;

  const PlannerScreen({super.key, Future<UserPosition?> Function()? positionFetcher})
    : positionFetcher = positionFetcher ?? LocationLookup.getCurrentPosition;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

enum Day { today, tomorrow }

class _PlannerScreenState extends State<PlannerScreen> {
  List<Activity>? _catalog;
  WeatherForecast _forecast = const WeatherForecast();
  Day _selectedDay = Day.today;

  final List<int> _kidAges = [4];
  final Set<String> _selectedInterests = {};
  final Set<String> _selectedParentInterests = {};
  Cost _budget = Cost.medium;
  bool _hasCar = true;
  bool _stayHome = false;

  bool _useMyPosition = false;
  double _maxDistanceKm = 5;
  UserPosition? _userPosition;
  bool _locatingPosition = false;
  String? _locationError;

  final ScrollController _hourlyScrollController = ScrollController();
  // Guards against re-scrolling on every rebuild (e.g. picking an interest
  // chip) — only auto-scroll once per fresh forecast/day so it doesn't
  // fight a user who has manually scrolled the strip elsewhere.
  bool _scrolledToCurrentHour = false;

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

  @override
  void dispose() {
    _hourlyScrollController.dispose();
    super.dispose();
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
      _scrolledToCurrentHour = false;
    });
  }

  static const _maxKids = 4;

  void _addKid() {
    if (_kidAges.length >= _maxKids) return;
    setState(() {
      _kidAges.add(4);
      _result = null;
    });
  }

  void _removeKid(int index) {
    if (_kidAges.length <= 1) return;
    setState(() {
      _kidAges.removeAt(index);
      _result = null;
    });
  }

  Future<void> _toggleUseMyPosition(bool value) async {
    setState(() {
      _useMyPosition = value;
      _result = null;
      _locationError = null;
    });
    if (!value) return;

    setState(() => _locatingPosition = true);
    final position = await widget.positionFetcher();
    if (!mounted) return;
    setState(() {
      _locatingPosition = false;
      _userPosition = position;
      if (position == null) {
        _locationError = 'Kunde inte hämta din position.';
        _useMyPosition = false; // fall back: filter stays off
      }
    });
  }

  Future<void> _spin() async {
    if (_catalog == null) return;
    setState(() {
      _loading = true;
      _result = null; // clear stale results while the new pick is computed
    });
    final useDistanceFilter = _useMyPosition && _userPosition != null && !_stayHome;
    final prefs = UserPreferences(
      kidAges: _kidAges,
      kidInterests: _selectedInterests.toList(),
      parentInterests: _selectedParentInterests.toList(),
      budget: _budget,
      hasCar: _hasCar,
      stayHome: _stayHome,
      maxDistanceKm: useDistanceFilter ? _maxDistanceKm : null,
      userLat: useDistanceFilter ? _userPosition!.lat : null,
      userLng: useDistanceFilter ? _userPosition!.lng : null,
    );
    // recommend() is synchronous (no network/IO) — a short artificial delay
    // gives the loading spinner below something to actually show.
    await Future.delayed(const Duration(milliseconds: 300));
    final result = ActivityRecommender().recommend(
      catalog: _catalog!,
      prefs: prefs,
      weather: _selectedWeather,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 80,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lightbulb_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Görabra'),
                  Text(
                    'Vad hittar vi på idag?',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.casino),
                  label: Text(_result == null ? 'Föreslå' : 'Föreslå igen'),
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
            _scrolledToCurrentHour = false;
          }),
        ),
        const SizedBox(height: 8),
        _buildWeatherSummary(),
        const SizedBox(height: 16),
        Text('Barnens åldrar', style: Theme.of(context).textTheme.titleMedium),
        for (var i = 0; i < _kidAges.length; i++) _buildKidAgeRow(i),
        TextButton.icon(
          onPressed: _kidAges.length >= _maxKids ? null : _addKid,
          icon: const Icon(Icons.add),
          label: const Text('Lägg till barn'),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: Text('Barnets intressen', style: Theme.of(context).textTheme.titleMedium),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
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
          ],
        ),
        ExpansionTile(
          title: Text(
            'Ditt intresse (bonus, filtrerar inte bort något)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
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
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Stanna hemma'),
          subtitle: const Text('Visa bara aktiviteter man kan göra hemma'),
          value: _stayHome,
          onChanged: (v) => setState(() {
            _stayHome = v;
            _result = null;
          }),
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
        const SizedBox(height: 8),
        ExpansionTile(
          title: Text('Avstånd', style: Theme.of(context).textTheme.titleMedium),
          subtitle: _stayHome
              ? const Text('Gäller inte när ni stannar hemma')
              : null,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Använd min position'),
              subtitle: _locatingPosition
                  ? const Text('Hämtar position…')
                  : _locationError != null
                  ? Text(_locationError!)
                  : null,
              value: _useMyPosition,
              onChanged: _stayHome ? null : (v) => _toggleUseMyPosition(v),
            ),
            Slider(
              value: _maxDistanceKm,
              min: 1,
              max: 50,
              divisions: 49,
              label: '${_maxDistanceKm.round()} km',
              onChanged: (_stayHome || !_useMyPosition || _userPosition == null)
                  ? null
                  : (v) => setState(() {
                      _maxDistanceKm = v;
                      _result = null;
                    }),
            ),
            Text('Max ${_maxDistanceKm.round()} km bort'),
          ],
        ),
      ],
    );
  }

  /// One removable age-slider row for a single kid (see design.md: reuses
  /// the same slider style as the original single-kid input, just repeated
  /// per kid in `_kidAges`).
  Widget _buildKidAgeRow(int index) {
    final age = _kidAges[index];
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Barn ${index + 1}: $age år'),
              Slider(
                value: age.toDouble(),
                min: 0,
                max: 12,
                divisions: 12,
                label: '$age',
                onChanged: (v) => setState(() {
                  _kidAges[index] = v.round();
                  _result = null;
                }),
              ),
            ],
          ),
        ),
        if (_kidAges.length > 1)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Ta bort barn ${index + 1}',
            onPressed: () => _removeKid(index),
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
    final currentIndex = hourly.indexWhere(
      (point) =>
          _selectedDay == Day.today &&
          point.time.year == now.year &&
          point.time.month == now.month &&
          point.time.day == now.day &&
          point.time.hour == now.hour,
    );
    if (currentIndex != -1 && !_scrolledToCurrentHour) {
      _scrolledToCurrentHour = true;
      // Scroll after this frame so the strip's viewport size is known;
      // each column is a fixed 56px wide (see _buildHourlyColumn).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hourlyScrollController.hasClients) return;
        final viewportWidth = _hourlyScrollController.position.viewportDimension;
        final target = (currentIndex * _hourlyColumnWidth - viewportWidth / 2 + _hourlyColumnWidth / 2)
            .clamp(0.0, _hourlyScrollController.position.maxScrollExtent);
        _hourlyScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
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
              controller: _hourlyScrollController,
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

  static const _hourlyColumnWidth = 56.0;

  Widget _buildHourlyColumn(HourlyPoint point, {required bool isCurrentHour}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: _hourlyColumnWidth,
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
                  if (!activity.homeOnly)
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${activity.location} · ${activity.openingHours}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
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
