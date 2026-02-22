import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:frontend/models/trip.dart';

class TripMapWidget extends StatelessWidget {
  final Trip trip;
  
  const TripMapWidget({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    if (trip.source['lat'] == null) {
       return Container(
         color: Colors.grey.shade200,
         child: const Center(child: Text("Map Location Unavailable")),
       );
    }
    
    final sourceLatLng = LatLng((trip.source['lat'] as num).toDouble(), (trip.source['lng'] as num).toDouble());
    
    Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('source'),
        position: sourceLatLng,
        infoWindow: InfoWindow(title: 'Start: ${trip.source['name']}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    };

    if (trip.destination['lat'] != null) {
       final destLatLng = LatLng((trip.destination['lat'] as num).toDouble(), (trip.destination['lng'] as num).toDouble());
       markers.add(
         Marker(
           markerId: const MarkerId('destination'),
           position: destLatLng,
           infoWindow: InfoWindow(title: 'End: ${trip.destination['name']}'),
           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
         )
       );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: sourceLatLng,
        zoom: 12.0,
      ),
      markers: markers,
      myLocationEnabled: false,
      zoomControlsEnabled: false,
    );
  }
}
