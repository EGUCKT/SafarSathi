import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// We use 'as' to give the library a nickname, this often forces VS Code to re-index it
import 'package:latlong2/latlong.dart';
import 'dart:developer';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Notice we now use ll.LatLng instead of just LatLng
    const initialLocation = LatLng(22.7196, 75.8577);

    return Scaffold(
      appBar: AppBar(
        title: const Text("SafarSathi Map"),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: initialLocation,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.ss1',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: initialLocation,
                width: 50,
                height: 50,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => log("Destination search clicked"),
        label: const Text("Where to?"),
        icon: const Icon(Icons.search),
        backgroundColor: Colors.red,
      ),
    );
  }
}