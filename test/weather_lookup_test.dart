import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gorabra/services/weather_lookup.dart';

void main() {
  test('clear condition swaps sun for moon at night', () {
    expect(iconForCondition(WeatherCondition.clear, isDay: true), Icons.wb_sunny);
    expect(iconForCondition(WeatherCondition.clear), Icons.wb_sunny); // default isDay: true
    expect(iconForCondition(WeatherCondition.clear, isDay: false), Icons.nightlight_round);
  });

  test('non-clear conditions are unaffected by isDay', () {
    expect(iconForCondition(WeatherCondition.cloudy, isDay: false), Icons.wb_cloudy);
    expect(iconForCondition(WeatherCondition.rain, isDay: false), Icons.umbrella);
  });
}
