import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Preview Map"),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(
              41.87147111568681, -87.66197876214603), // Initial coordinates
          zoom: 14.0, // for zoom
        ),
        onMapCreated: (GoogleMapController controller) {
          
        },
      ),
    );
  }
}
