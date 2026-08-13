import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/activity.dart';
import '../models/activity_catalog.dart';
import '../services/location_lookup.dart';
import '../services/recommender.dart';
import '../services/weather_lookup.dart';

// ponytail: only strict "HH:MM–HH:MM" (no trailing qualifier like
// "(vardagar)") is parsed; anything else (free text, seasonal, day
// qualifiers) returns null rather than guessing. Upgrade path: add
// day-qualifier parsing if the dataset gains many such entries.
final _hoursPattern = RegExp(
  r'^([01]\d|2[0-3]):([0-5]\d)[–-]([01]\d|2[0-3]):([0-5]\d)$',
);

/// Returns whether [openingHours] indicates the activity is open at [now]
/// (defaults to the current wall-clock time), or `null` if the text isn't a
/// strict "HH:MM–HH:MM" range and open/closed can't be reliably computed.
bool? isOpenNow(String openingHours, {DateTime? now}) {
  final match = _hoursPattern.firstMatch(openingHours.trim());
  if (match == null) return null;

  final openMinutes =
      int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  final closeMinutes =
      int.parse(match.group(3)!) * 60 + int.parse(match.group(4)!);
  // ponytail: overnight ranges (close <= open, e.g. "22:00–02:00") aren't
  // handled — return null rather than silently reporting "closed" all
  // night. Upgrade path: wrap-around comparison if the dataset gains one.
  if (closeMinutes <= openMinutes) return null;
  final clock = now ?? DateTime.now();
  final nowMinutes = clock.hour * 60 + clock.minute;
  return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
}

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

/// Swedish weekday abbreviations, `DateTime.weekday`-indexed (1 = Monday).
const _swedishWeekdays = [
  'Måndag',
  'Tisdag',
  'Onsdag',
  'Torsdag',
  'Fredag',
  'Lördag',
  'Söndag',
];

/// "Idag Tisdag 11/8" for today; plain "Imorgon" for tomorrow — device-clock
/// based since this is just a label, unlike the weather fetch's
/// Stockholm-local day matching.
String _dayLabel(Day day) {
  if (day == Day.tomorrow) return 'Imorgon';
  final now = DateTime.now();
  final weekday = _swedishWeekdays[now.weekday - 1];
  return 'Idag $weekday ${now.day}/${now.month}';
}

/// Single screen: input form (5.1), spin/result display (5.2), re-spin
/// (5.3), and closest-matches fallback results shown unlabeled (5.4).
class PlannerScreen extends StatefulWidget {
  /// Injectable position fetcher — defaults to real GPS via
  /// [LocationLookup], overridable in tests (mirrors the `Random? random`
  /// seam already used in [ActivityRecommender]).
  final Future<UserPosition?> Function() positionFetcher;

  const PlannerScreen({
    super.key,
    Future<UserPosition?> Function()? positionFetcher,
  }) : positionFetcher = positionFetcher ?? LocationLookup.getCurrentPosition;

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
  static const _budgetCeilingSek = 3000;
  // Starts at the ceiling (no filtering) so a fresh spin shows all
  // activities regardless of cost — 0 means "free only" and is a real
  // user-selectable filter, not the default/unset state.
  int _budgetSek = _budgetCeilingSek;
  final TextEditingController _budgetController = TextEditingController(
    text: '$_budgetCeilingSek',
  );
  final FocusNode _budgetFocusNode = FocusNode();
  bool _hasCar = true;
  bool _stayHome = false;
  bool _indoorOnly = false;

  bool _useMyPosition = false;
  double _maxDistanceKm = 5;
  UserPosition? _userPosition;
  bool _locatingPosition = false;
  String? _locationError;

  final GlobalKey _spinButtonKey = GlobalKey();

  final ScrollController _hourlyScrollController = ScrollController();
  // Guards against re-scrolling on every rebuild (e.g. picking an interest
  // chip) — only auto-scroll once per fresh forecast/day so it doesn't
  // fight a user who has manually scrolled the strip elsewhere.
  bool _scrolledToCurrentHour = false;

  WeatherResult? get _selectedWeather => _forecast.middayResult(
    _selectedDay == Day.today ? _forecast.today : _forecast.tomorrow,
  );

  List<HourlyPoint> get _selectedHourly =>
      _selectedDay == Day.today ? _forecast.today : _forecast.tomorrow;

  RecommendationResult? _result;
  bool _loading = false;
  String? _loadError;

  // Back/forward history of past spins (browser-tab semantics: spinning
  // again after navigating back truncates the abandoned forward entries).
  final List<RecommendationResult> _history = [];
  int _historyIndex = -1;

  // All activity ids shown so far under the current filters — fed to the
  // recommender as excludeIds so it cycles through the whole eligible pool
  // before repeating, instead of only avoiding the immediately previous
  // spin (see recommender.dart's top-up fallback, which naturally resets
  // once every id has been shown once). Cleared alongside _clearResult()
  // whenever a filter changes, since the eligible pool itself changes.
  final Set<String> _shownIds = {};

  // Bumped on every filter change; a spin captures the generation before
  // its artificial delay and discards its result if the generation moved
  // on in the meantime (filters changed mid-flight) — otherwise a stale
  // spin would commit a result/history entry computed against prefs the
  // user has since changed, and would corrupt `_shownIds` bookkeeping for
  // the new filter's pool.
  int _spinGeneration = 0;

  void _clearResult() {
    _result = null;
    _history.clear();
    _historyIndex = -1;
    _shownIds.clear();
    _spinGeneration++;
    // A spin in flight when this fires will be discarded once its delay
    // ends (see `_spin()`'s generation check) — reset the spinner now
    // rather than leaving it stuck forever waiting for a result that will
    // never be committed.
    _loading = false;
  }

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _loadWeather();
    // Show "Gratis" instead of a bare "0" once the user taps away — while
    // focused, leave the field alone so a fresh digit isn't typed after it.
    _budgetFocusNode.addListener(() {
      if (!_budgetFocusNode.hasFocus) _syncBudgetDisplay();
    });
  }

  @override
  void dispose() {
    _hourlyScrollController.dispose();
    _budgetController.dispose();
    _budgetFocusNode.dispose();
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
      _clearResult();
      _scrolledToCurrentHour = false;
    });
  }

  static const _maxKids = 4;

  void _addKid() {
    if (_kidAges.length >= _maxKids) return;
    setState(() {
      _kidAges.add(4);
      _clearResult();
    });
  }

  void _removeKid(int index) {
    if (_kidAges.length <= 1) return;
    setState(() {
      _kidAges.removeAt(index);
      _clearResult();
    });
  }

  /// Displays "Gratis" instead of a bare "0" when the field isn't
  /// focused, so the user isn't left staring at a number for free.
  void _syncBudgetDisplay() {
    _budgetController.text = _budgetSek == 0 ? 'Gratis' : '$_budgetSek';
  }

  /// Used by the slider — keeps the textfield's displayed value in sync.
  void _setBudgetFromSlider(int sek) {
    setState(() {
      _budgetSek = sek;
      _clearResult();
    });
    _syncBudgetDisplay();
  }

  /// Used by the textfield — only rewrites the field's text when the
  /// typed value had to be clamped, so a normal keystroke never resets
  /// the cursor mid-edit. Unparseable/empty text (still-typing state,
  /// e.g. after select-all-delete) leaves `_budgetSek` untouched instead
  /// of silently applying a 0 kr (free-only) filter behind the user's back.
  void _setBudgetFromField(String text) {
    final parsed = int.tryParse(text);
    if (parsed == null) return;
    final clamped = parsed.clamp(0, _budgetCeilingSek);
    setState(() {
      _budgetSek = clamped;
      _clearResult();
    });
    if (clamped != parsed) {
      _budgetController.text = '$clamped';
    }
  }

  Future<void> _toggleUseMyPosition(bool value) async {
    setState(() {
      _useMyPosition = value;
      _clearResult();
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
      // Keep showing the previous result while the new pick is computed —
      // clearing it here shrinks the list and clamps scroll to top, which
      // fights the scroll-to-results animation once the new result lands.
    });
    final useDistanceFilter =
        _useMyPosition && _userPosition != null && !_stayHome;
    final prefs = UserPreferences(
      kidAges: _kidAges,
      kidInterests: _selectedInterests.toList(),
      maxBudgetSek: _budgetSek,
      hasCar: _hasCar,
      stayHome: _stayHome,
      indoorOnly: _indoorOnly,
      maxDistanceKm: useDistanceFilter ? _maxDistanceKm : null,
      userLat: useDistanceFilter ? _userPosition!.lat : null,
      userLng: useDistanceFilter ? _userPosition!.lng : null,
    );
    // Snapshot before the delay below — history navigation (back/forward)
    // isn't gated by `_loading`, but only mutates `_result`/`_historyIndex`,
    // never `_shownIds`; a filter change (which does mutate `_shownIds`) is
    // guarded separately below via `_spinGeneration`.
    final excludeIds = Set<String>.from(_shownIds);
    final generation = _spinGeneration;
    // recommend() is synchronous (no network/IO) — a short artificial delay
    // gives the loading spinner below something to actually show.
    await Future.delayed(const Duration(milliseconds: 300));
    final result = ActivityRecommender().recommend(
      catalog: _catalog!,
      prefs: prefs,
      weather: _selectedWeather,
      excludeIds: excludeIds,
    );
    // A filter changed while this spin was in flight — its result was
    // computed against now-stale prefs/excludeIds, so discard it rather
    // than committing a result/history entry or `_shownIds` update for the
    // wrong pool.
    if (!mounted || generation != _spinGeneration) return;
    setState(() {
      // New spin from any history position drops abandoned forward entries.
      _history.removeRange(_historyIndex + 1, _history.length);
      _history.add(result);
      _historyIndex = _history.length - 1;
      _result = result;
      _loading = false;
      // Once every eligible activity has been shown at least once, start a
      // fresh cycle — otherwise the exclude set would keep growing until
      // it covers the whole pool and stays that way forever, making every
      // future spin fall straight to the top-up fallback instead of
      // actually cycling through activities. Seed the new cycle with just
      // this spin's ids (rather than clearing to empty) so the activities
      // shown right now can't immediately repeat on the very next spin.
      final newIds = result.activities.map((a) => a.id);
      _shownIds.addAll(newIds);
      if (_shownIds.length >= result.eligiblePoolSize) {
        _shownIds
          ..clear()
          ..addAll(newIds);
      }
    });
    // Scroll button to top of viewport so it stays reachable for re-spin
    // while the fresh suggestions below it come into view — avoids users
    // having to scroll manually to see results.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final buttonContext = _spinButtonKey.currentContext;
      if (buttonContext == null) return;
      Scrollable.ensureVisible(
        buttonContext,
        alignment: 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _goBack() {
    if (_historyIndex <= 0) return;
    setState(() {
      _historyIndex--;
      _result = _history[_historyIndex];
    });
  }

  void _goForward() {
    if (_historyIndex >= _history.length - 1) return;
    setState(() {
      _historyIndex++;
      _result = _history[_historyIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 140,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Om appen',
            onPressed: () => _showAboutSheet(context),
          ),
        ],
        title: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/logo_proposals/logo.png', height: 80),
              const SizedBox(height: 4),
              const Text(
                'Tips på aktiviteter i Götet med barnen',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      // Weather strip pinned outside the scrollable body — same widget as
      // before, just relocated so it stays visible while browsing results
      // further down, instead of scrolling away with the rest of the form.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _buildWeatherSummary(),
          ),
          Expanded(
            child: _loadError != null
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _historyIndex > 0 ? _goBack : null,
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Föregående förslag',
                          ),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: FilledButton.icon(
                                key: _spinButtonKey,
                                onPressed: _loading ? null : _spin,
                                style: FilledButton.styleFrom(
                                  textStyle: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 15,
                                  ),
                                ),
                                icon: _loading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : const Icon(Icons.casino, size: 24),
                                label: Text(
                                  _result == null
                                      ? 'Ge mig tips!'
                                      : 'Nya förslag',
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _historyIndex < _history.length - 1
                                ? _goForward
                                : null,
                            icon: const Icon(Icons.arrow_forward),
                            tooltip: 'Nästa förslag',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_result != null) _buildResults(_result!),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<Day>(
          segments: [
            ButtonSegment(value: Day.today, label: Text(_dayLabel(Day.today))),
            ButtonSegment(
              value: Day.tomorrow,
              label: Text(_dayLabel(Day.tomorrow)),
            ),
          ],
          selected: {_selectedDay},
          onSelectionChanged: (s) => setState(() {
            _selectedDay = s.first;
            _clearResult();
            _scrolledToCurrentHour = false;
          }),
        ),
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
          key: const Key('moreFiltersTile'),
          title: Text('Filter', style: Theme.of(context).textTheme.titleMedium),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            ExpansionTile(
              title: Text(
                'Intressen',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                        _clearResult();
                      }),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Budget', style: Theme.of(context).textTheme.titleMedium),
            Text(
              'Totalt för hela utflykten, inte per person',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Slider(
                    key: const Key('budgetSlider'),
                    min: 0,
                    max: _budgetCeilingSek.toDouble(),
                    divisions: _budgetCeilingSek ~/ 50,
                    value: _budgetSek.toDouble(),
                    label: _budgetSek == 0 ? 'Gratis' : '$_budgetSek kr',
                    onChanged: (v) => _setBudgetFromSlider(v.round()),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: TextField(
                    key: const Key('budgetField'),
                    controller: _budgetController,
                    focusNode: _budgetFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.end,
                    decoration: InputDecoration(
                      suffixText: _budgetSek == 0 ? null : 'kr',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: _setBudgetFromField,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tillgång till bil?'),
              subtitle: _hasCar
                  ? null
                  // ponytail: passive hint only — no auto-enabling location,
                  // granting GPS access is the user's call via Avstånd below.
                  : const Text(
                      'Tips: sätt ett avstånd nedan om ni inte har bil',
                    ),
              value: _hasCar,
              onChanged: (v) => setState(() {
                _hasCar = v;
                _clearResult();
              }),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Stanna hemma'),
              subtitle: const Text('Visa bara aktiviteter man kan göra hemma'),
              value: _stayHome,
              onChanged: (v) => setState(() {
                _stayHome = v;
                _clearResult();
              }),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Inomhusaktiviteter'),
              // ponytail: no-op when stayHome is on (every homeOnly activity
              // is already indoor) — disable instead of letting the user
              // toggle something with no effect.
              subtitle: _stayHome
                  ? const Text('Alla hemmaaktiviteter är inomhus')
                  : const Text('Visa bara inomhusaktiviteter'),
              value: _indoorOnly,
              onChanged: _stayHome
                  ? null
                  : (v) => setState(() {
                      _indoorOnly = v;
                      _clearResult();
                    }),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: Text(
                'Avstånd',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                  onChanged:
                      (_stayHome || !_useMyPosition || _userPosition == null)
                      ? null
                      : (v) => setState(() {
                          _maxDistanceKm = v;
                          _clearResult();
                        }),
                ),
                Text('Max ${_maxDistanceKm.round()} km bort'),
              ],
            ),
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
              Text('$age år'),
              Slider(
                value: age.toDouble(),
                min: 0,
                max: 12,
                divisions: 12,
                label: '$age',
                onChanged: (v) => setState(() {
                  _kidAges[index] = v.round();
                  _clearResult();
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
        final viewportWidth =
            _hourlyScrollController.position.viewportDimension;
        final target =
            (currentIndex * _hourlyColumnWidth -
                    viewportWidth / 2 +
                    _hourlyColumnWidth / 2)
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Väder i Göteborg',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        IntrinsicHeight(
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
        ),
      ],
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
                iconForCondition(point.condition, isDay: point.isDay),
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
          // Wind: small and muted, like the hour label — Gothenburg's
          // coastal wind varies enough hour-to-hour that a single daily
          // number would hide real swings, so this shows per-hour m/s.
          Expanded(
            child: Center(
              child: Text(
                '${point.windSpeedMs.round()} m/s',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isCurrentHour
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
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
  /// (matching the four Expanded bands in each hourly column) rather than
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
          Expanded(
            child: Center(
              child: Icon(Icons.schedule, size: 16, color: mutedStyle?.color),
            ),
          ),
          const Expanded(
            child: Center(
              child: Icon(
                Icons.cloud_outlined,
                size: 24,
                color: Colors.transparent,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(Icons.thermostat, size: 16, color: mutedStyle?.color),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(Icons.air, size: 16, color: mutedStyle?.color),
            ),
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
        for (final (index, activity) in result.activities.indexed)
          _FadeInCard(
            // Key ties identity to this spin + slot so the fade replays
            // every time _spin() produces a new result (rung 2: stdlib
            // TweenAnimationBuilder, no AnimationController needed).
            key: ValueKey('$_historyIndex-${activity.id}'),
            delay: Duration(milliseconds: index * 200),
            child: _buildActivityCard(activity),
          ),
        const SizedBox(height: 4),
        Text(
          'Dubbelkolla alltid aktuella öppettider och priser',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.red.shade900),
        ),
      ],
    );
  }

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Om Hittepå', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                'Hittepå finns för att ibland vill man bara enkelt ha '
                'några snabba tips på vad man kan hitta på med barnen i '
                'Göteborg. Utan att behöva installera appar, gå igenom '
                'Facebook grupper, Instagram konton eller event kalendrar.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Vill du vara mer precis går det att filtrera aktiviteter '
                'utifrån intressen, ålder, budget, tillgång till bil, '
                'närhet - position (om du väljer att dela den) används '
                'bara lokalt på telefonen.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Dubbelkolla alltid aktuella öppettider och priser innan ni '
                'åker, eftersom dessa kan ändras utan att appen hunnit uppdaterats.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenNowRow(String openingHours) {
    final isOpen = isOpenNow(openingHours);
    if (isOpen == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            isOpen ? 'Öppet nu' : 'Stängt nu',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Activity activity) {
    return Card(
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
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${activity.location} · ${activity.openingHours}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            if (!activity.homeOnly && _selectedDay == Day.today)
              _buildOpenNowRow(activity.openingHours),
            const SizedBox(height: 8),
            Text(
              activity.benefitNote,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and slides [child] in after [delay]. New instances (distinguished
/// by widget `key`) replay the animation — used to stagger result cards
/// 1, 2, 3 on each spin.
class _FadeInCard extends StatelessWidget {
  const _FadeInCard({super.key, required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300) + delay,
      curve: Curves.linear,
      builder: (context, t, child) {
        // t is linear in real time here (curve applied below, after the
        // delay subtraction) — hold at 0 during the per-card delay, then
        // ease in over the remaining time. Avoids needing a Future/Timer.
        final delayFraction =
            delay.inMilliseconds / (300 + delay.inMilliseconds);
        final linearProgress = ((t - delayFraction) / (1 - delayFraction))
            .clamp(0.0, 1.0);
        final progress = Curves.easeOut.transform(linearProgress);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, (1 - progress) * 16),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
