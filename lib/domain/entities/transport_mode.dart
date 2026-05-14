import 'package:flutter/material.dart';

/// 移動手段。TopicCategory.transport の細分化。
enum TransportMode {
  walk('徒歩', Icons.directions_walk_rounded),
  train('電車', Icons.directions_subway_rounded),
  bus('バス', Icons.directions_bus_rounded),
  car('車', Icons.directions_car_rounded),
  taxi('タクシー', Icons.local_taxi_rounded),
  plane('飛行機', Icons.flight_rounded),
  ship('船', Icons.directions_boat_rounded);

  const TransportMode(this.label, this.icon);

  final String label;
  final IconData icon;
}
