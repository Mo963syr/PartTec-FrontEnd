import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DeliveryMapPage extends StatelessWidget {
  final double lat;
  final double lng;
  final String customerName;

  const DeliveryMapPage({
    Key? key,
    required this.lat,
    required this.lng,
    required this.customerName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final LatLng location = LatLng(lat, lng);

    return Scaffold(
      appBar: AppBar(
        title: Text('موقع الزبون: $customerName'),
      ),
      body: FlutterMap(
        options: MapOptions(
          center: location,
          zoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                width: 80,
                height: 80,
                point: location,
                child: Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
