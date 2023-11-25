import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:fsp/MapUtils.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:fsp/RealtimeNav.dart';

class PreviewScreen extends StatefulWidget {
  final DetailsResult? startPosition;
  final DetailsResult? endPosition;

  const PreviewScreen({Key? key, this.startPosition, this.endPosition})
      : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<PreviewScreen> {
  bool _isNavigationStarted = false; // new line added for calm routes
  late CameraPosition _initialPosition;
  final Completer<GoogleMapController> _controller = Completer();
  List<Polyline> _polylines = [];
  late String _selectedPolylineDistance = '';
  StreamController<LatLng> _locationUpdateController =
      StreamController<LatLng>();
  // int _selectedPolylineIndex = -1;

  Future<List<List<LatLng>>> getDirections() async {
    final apiKey = 'AIzaSyDkKbK_K-0WJuhGvvSbmSL5pEoCiBSWNqY';
    final apiUrl =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${widget.startPosition!.geometry!.location!.lat},${widget.startPosition!.geometry!.location!.lng}&destination=${widget.endPosition!.geometry!.location!.lat},${widget.endPosition!.geometry!.location!.lng}&mode=bicycling&key=$apiKey&alternatives=true';

    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final decodedResponse = json.decode(response.body);
      List<List<LatLng>> routes = [];

      if (decodedResponse['status'] == 'OK') {
        for (var route in decodedResponse['routes']) {
          List<LatLng> points = [];

          for (var leg in route['legs']) {
            for (var step in leg['steps']) {
              points.add(LatLng(
                step['start_location']['lat'],
                step['start_location']['lng'],
              ));
              points.add(LatLng(
                step['end_location']['lat'],
                step['end_location']['lng'],
              ));
            }
          }

          routes.add(points);
        }
      }

      return routes;
    } else {
      throw Exception('Failed to load directions');
    }
  }

  void _addPolylines() async {
    List<List<LatLng>> routes = await getDirections();

    _polylines.clear(); // Clears all the previous polylines NEW
    double minDistance = double.infinity; // Initialize with a large value  NEW
    int calmRouteIndex = 0; // Index of the calm route NEW

    for (int i = 0; i < routes.length; i++) {
      PolylineId polylineId = PolylineId('polyline_$i');
      Color color = _getRandomColor();
      int width = 5; //for non - calm routes
      // Check if this is the calm route and set a different width
      if (i == calmRouteIndex) {
        color = Color.fromARGB(255, 12, 240, 12); // Green color for calm route
        width = 14; // Increase width for the calm route
      }
      _polylines.add(Polyline(
        polylineId: polylineId,
        color: color,
        width: width,
        points: routes[i],
        onTap: () {
          _onPolylineTapped(routes[i]);
        },
      ));
      // Calculate distance for each route and find the calm route
      double distance = _calculateDistance(routes[i]);
      if (distance < minDistance) {
        minDistance = distance;
        calmRouteIndex = i;
      }
    }

    double distance = _calculateDistance(routes[0]);
    _selectedPolylineDistance = distance.toStringAsFixed(2);

    setState(() {
      _isNavigationStarted = true;
    });
  }

  Color _getRandomColor() {
    return Color((math.Random().nextDouble() * 0xFFFFFF).toInt() << 0)
        .withOpacity(1.0);
  }

  void _onPolylineTapped(List<LatLng> polylinePoints) {
    double distance = _calculateDistance(polylinePoints);
    String distanceString = distance.toStringAsFixed(2);
    setState(() {
      _selectedPolylineDistance = distanceString;
    });

    // printing distance to destination
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Distance: $_selectedPolylineDistance miles',
            style: TextStyle(fontSize: 18.0),
          ),
        );
      },
    );
  }

  double _calculateDistance(List<LatLng> polylinePoints) {
    double distance = 0.0;

    for (int i = 0; i < polylinePoints.length - 1; i++) {
      distance += _calculateDistanceBetweenPoints(
        polylinePoints[i].latitude,
        polylinePoints[i].longitude,
        polylinePoints[i + 1].latitude,
        polylinePoints[i + 1].longitude,
      );
    }

    return distance;
  }

  double _calculateDistanceBetweenPoints(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 3958.8; // for getting distance in miles

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  Future<void> _showSOSDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // tap button for close dialog!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Call 911'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Do you want to call 911?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                // Implement your "Yes" logic here
                print("Calling 911");
                Navigator.of(context).pop();
              },
              child: Text('Yes'),
            ),
            TextButton(
              onPressed: () {
                // Implement your "No" logic here
                print("Cancel SOS");
                Navigator.of(context).pop();
              },
              child: Text('No'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initialPosition = CameraPosition(
      target: LatLng(widget.startPosition!.geometry!.location!.lat!,
          widget.startPosition!.geometry!.location!.lng!),
      zoom: 14.0,
    );
    _addPolylines();
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> _markers = {
      Marker(
        markerId: MarkerId('start'),
        position: LatLng(
          widget.startPosition!.geometry!.location!.lat!,
          widget.startPosition!.geometry!.location!.lng!,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      Marker(
        markerId: MarkerId('end'),
        position: LatLng(
          widget.endPosition!.geometry!.location!.lat!,
          widget.endPosition!.geometry!.location!.lng!,
        ),
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text("Preview"),
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: CircleAvatar(
            backgroundColor: Colors.blue,
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: Set.from(_markers),
            polylines: Set.from(_polylines),
            onMapCreated: (GoogleMapController controller) {
              Future.delayed(
                Duration(milliseconds: 200),
                () => controller.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    MapUtils.boundsFromLatLngList(
                      _markers.map((loc) => loc.position).toList(),
                    ),
                    30,
                  ),
                ),
              );
            },
          ),
          if (_selectedPolylineDistance.isNotEmpty)
            Positioned(
              bottom: 30.0,
              left: 27.0,
              right: 27.0,
              child: Container(
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      offset: Offset(0.0, 2.0),
                      blurRadius: 6.0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RealtimeNav(
                              startLocation: LatLng(
                                widget.startPosition!.geometry!.location!.lat!,
                                widget.startPosition!.geometry!.location!.lng!,
                              ),
                              destination: LatLng(
                                widget.endPosition!.geometry!.location!.lat!,
                                widget.endPosition!.geometry!.location!.lng!,
                              ),
                              locationUpdateController:
                                  _locationUpdateController,
                            ),
                          ),
                        );
                      },
                      child: Text("Start Navigation"),
                    ),
                    SizedBox(height: 8.0),
                    Text(
                      'Distance to Destination: $_selectedPolylineDistance miles',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20.0),
                    ),
                  ],
                ),
              ),
            ),
          if (_selectedPolylineDistance.isNotEmpty)
            Positioned(
              bottom: 30.0,
              left: 27.0,
              right: 27.0,
              child: Container(
                  // ...
                  ),
            ),
          Positioned(
            top: 50.0,
            right: 20.0,
            child: ElevatedButton(
              onPressed: () {
                // To show SOS dialog
                _showSOSDialog();
              },
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(20),
                primary: Colors.red,
              ),
              child: Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationUpdateController.close();
    super.dispose();
  }
}
