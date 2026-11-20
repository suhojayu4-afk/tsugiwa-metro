import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/weather/weather_source.dart';
import 'pixel_ui.dart';
import 'scene_events.dart';

part 'scene_ambience.dart';
part 'scene_art.dart';
part 'scene_banner.dart';
part 'scene_look.dart';
part 'scene_painter.dart';
part 'scene_passengers.dart';
part 'scene_signs.dart';
part 'scene_train.dart';
part 'scene_weather.dart';

enum DayPart { day, evening, night }

DayPart dayPartOf(DateTime t) => switch (t.hour) {
  >= 5 && < 16 => DayPart.day,
  >= 16 && < 19 => DayPart.evening,
  _ => DayPart.night,
};
