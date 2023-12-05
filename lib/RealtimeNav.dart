import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' show pi, log, tan, atan2, min, max;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'dart:math' show pi, sin, cos, sqrt, asin;
import 'package:wakelock/wakelock.dart';

IconData getInstructionIcon(String instruction) {
  if (instruction.contains("left")) {
    return Icons.turn_left_outlined; // Icon for left turn
  } else if (instruction.contains("right")) {
    return Icons.turn_right_outlined; // Icon for right turn
  } else if (instruction.contains("straight")) {
    return Icons.straight_outlined; // Icon for going straight
  } else if (instruction.toLowerCase().contains("start")) {
    return Icons.flag; // Icon for starting point
  } else if (instruction.toLowerCase().contains("arrived")) {
    return Icons.location_on; // Icon for arrival
  }
  // Add more conditions for different instructions as needed

  return Icons.navigation; // Default icon
}

class RealtimeNav extends StatefulWidget {
  final LatLng startLocation;
  final LatLng destination;
  final StreamController<LatLng> locationUpdateController;

  RealtimeNav({
    required this.startLocation,
    required this.destination,
    required this.locationUpdateController,
  });

  @override
  _RealtimeNavState createState() =>
      _RealtimeNavState(locationUpdateController: locationUpdateController);
}

class NavigationStep {
  String instruction;
  LatLng endLocation;

  NavigationStep(this.instruction, this.endLocation);
}

// Global variables
List<NavigationStep> globalNavigationSteps = [];
int currentStepIndex = 0;

class _RealtimeNavState extends State<RealtimeNav> {
  StreamSubscription? _locationSubscription;
  LatLng? _previousPosition;
  GoogleMapController? _controller;
  final StreamController<LatLng> locationUpdateController;
  LatLng _currentLocation = LatLng(0.0, 0.0);
  bool _isSatelliteView = false;
  bool _showBusStops = false;
  // Map<PolylineId, Polyline> _polylines = {};
  Set<Polyline> _polylines = {};
  Set<Marker> _busStopMarkers = {};
  String _currentInstruction =
      "Start Navigation"; // State variable for current instruction
  bool _isNightMode = false; // for changing modes
  FlutterTts flutterTts = FlutterTts();
  bool isMuted = false;
  bool _hasNavigationStarted = false;
  late String _darkMapStyle;
  late String _lightMapStyle;
  Set<Marker> _markers = Set<Marker>();
  bool setFirstTime = true;

  late StreamSubscription<Position> _positionStream;

  _RealtimeNavState({required this.locationUpdateController});

  Future<void> _loadMapStyles() async {
    _darkMapStyle = await rootBundle.loadString('assets/map_style/dark.json');
    _lightMapStyle = await rootBundle.loadString('assets/map_style/light.json');
  }

  void _toggleNightMode() {
    setState(() {
      _isNightMode = !_isNightMode;
      if (_controller != null) {
        if (_isNightMode) {
          _controller?.setMapStyle(_darkMapStyle);
        } else {
          _controller?.setMapStyle(_lightMapStyle);
        }
      }
    });
  }

  @override
  void initState() {
    // _initializeLocationAndCompass();
    super.initState();
    Wakelock.enable();
    // Initialize destination marker
    _markers.add(
      Marker(
        markerId: MarkerId('destination'),
        position: widget.destination,
        infoWindow: InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      _updateCurrentLocationMarker(
          LatLng(position.latitude, position.longitude));

      _checkProximityAndAnnounceDirections(position);
    });
    widget.locationUpdateController.stream.listen((location) async {
      setState(() {
        if (setFirstTime) {
          setFirstTime = !setFirstTime;
          _currentLocation = location;
        }
      });
      // Configuring text to speech
      flutterTts.setStartHandler(() {
        print("Text to speech started");
      });
      flutterTts.setCompletionHandler(() {
        print("Text to speech completed");
      });
      flutterTts.setErrorHandler((msg) {
        print("Text to speech Error: $msg");
      });

      // Start navigation directions
      if (!_isNightMode && !_showBusStops) {
        _speakNavigationDirections(_currentInstruction);
      }
    });
    _loadMapStyles();
  }

  void _initializeLocationStream() {
    _locationSubscription = Geolocator.getPositionStream().listen(
      (Position position) {
        if (_previousPosition != null) {
          final bearing = _getBearing(
            LatLng(_previousPosition!.latitude, _previousPosition!.longitude),
            LatLng(position.latitude, position.longitude),
          );
          _updateMapBearing(bearing, position);
        }
        _previousPosition = LatLng(position.latitude, position.longitude);
      },
    );
  }

  double _getBearing(LatLng start, LatLng end) {
    var startLat = start.latitude * pi / 180;
    var startLng = start.longitude * pi / 180;
    var endLat = end.latitude * pi / 180;
    var endLng = end.longitude * pi / 180;

    var dLng = endLng - startLng;
    var dPhi =
        log(tan(endLat / 2.0 + pi / 4.0) / tan(startLat / 2.0 + pi / 4.0));

    if (dLng.abs() > pi) {
      if (dLng > 0.0) {
        dLng = -(2.0 * pi - dLng);
      } else {
        dLng = (2.0 * pi + dLng);
      }
    }

    return (atan2(dLng, dPhi) * 180 / pi + 360) % 360;
  }

  void _updateMapBearing(double bearing, Position position) {
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          bearing: bearing,
          zoom: 18.0,
        ),
      ),
    );
  }

  void _updateCurrentLocationMarker(LatLng newLocation) {
    setState(() {
      _currentLocation = newLocation;

      Marker? currentMarker;
      for (var marker in _markers) {
        if (marker.markerId == MarkerId('currentLocation')) {
          currentMarker = marker;
          break; // Stop the loop if we have found our marker
        }
      }

      if (currentMarker != null) {
        _markers.remove(currentMarker);
      }

      _markers.add(Marker(
        markerId: MarkerId('currentLocation'),
        position: _currentLocation,
        infoWindow: InfoWindow(title: 'Current Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    });
  }

  void _checkProximityAndAnnounceDirections(Position currentPosition) {
    if (currentStepIndex < globalNavigationSteps.length) {
      double distance = _calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        globalNavigationSteps[currentStepIndex].endLocation.latitude,
        globalNavigationSteps[currentStepIndex].endLocation.longitude,
      );

      if (distance <= 30) {
        // Announce the direction for the next step (if available)
        if (currentStepIndex < globalNavigationSteps.length - 1) {
          String nextInstruction =
              globalNavigationSteps[currentStepIndex + 1].instruction;
          _speakNavigationDirections(nextInstruction);
          setState(() {
            _currentInstruction =
                nextInstruction; // Update the instruction to be displayed
          });

          // Increment the index or set a timer to repeat the instruction
          // Ensure the instruction is not repeated too frequently
        }

        if (currentStepIndex == globalNavigationSteps.length - 1) {
          String nextInstruction = "You have reached your destination.";
          _speakNavigationDirections(nextInstruction);
          setState(() {
            _currentInstruction =
                nextInstruction; // Update the instruction to be displayed
          });
        }
        currentStepIndex++; // Move to the next step
      }
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double radiusOfEarth = 6371; // Earth's radius in kilometers
    double lat1Rad = _degreesToRadians(lat1);
    double lat2Rad = _degreesToRadians(lat2);
    double deltaLatRad = _degreesToRadians(lat2 - lat1);
    double deltaLonRad = _degreesToRadians(lon2 - lon1);

    // Haversine formula
    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLonRad / 2) *
            sin(deltaLonRad / 2);
    double c = 2 * asin(sqrt(a));
    double distance = radiusOfEarth * c;

    return distance * 1000; // Convert to meters
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  // void _updateCurrentLocationMarker(LatLng newLocation) {
  //   setState(() {
  //     _currentLocation = newLocation;

  //     Marker? currentMarker;
  //     for (var marker in _markers) {
  //       if (marker.markerId == MarkerId('currentLocation')) {
  //         currentMarker = marker;
  //         break; // Stop the loop if we have found our marker
  //       }
  //     }

  //     if (currentMarker != null) {
  //       _markers.remove(currentMarker);
  //     }
  //     _markers.add(Marker(
  //       markerId: MarkerId('currentLocation'),
  //       position: _currentLocation,
  //       infoWindow: InfoWindow(title: 'Current Location'),
  //       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
  //     ));
  //   });
  // }

  @override
  void dispose() {
    // Cancel the location updates stream when the widget is disposed
    Wakelock.disable();
    _positionStream.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  Widget _buildInstructionBox() {
    return Positioned(
      top: 40.0,
      left: 10.0,
      right: 10.0,
      child: AnimatedOpacity(
        opacity: _currentInstruction.isNotEmpty ? 1.0 : 0.0,
        duration: Duration(milliseconds: 500),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
          decoration: BoxDecoration(
            color: _isNightMode ? Colors.black87 : Colors.white70,
            borderRadius: BorderRadius.circular(10.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                getInstructionIcon(
                    _currentInstruction), // Example icon, choose one that fits the instruction
                color: _isNightMode ? Colors.white : Colors.black,
                size: 50.0,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentInstruction,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: _isNightMode ? Colors.white : Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2, // Allows text to span up to 2 lines
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text("Bike Navigation"),
      // ),
      body: FutureBuilder(
        future: Future.delayed(Duration(milliseconds: 200)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                _buildMap(),
                _buildInstructionBox(), // Add this line
                // You can add more overlay widgets here if needed
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'zoomInButton',
            onPressed: () {
              if (_currentLocation != null) {
                _startBikeNavigation(origin: _currentLocation);
              } else {
                print('Current location is not available.');
              }
            },
            child: Icon(Icons.restart_alt),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'zoomInButton',
            onPressed: _zoomIn,
            child: Icon(Icons.zoom_in),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'zoomOutButton',
            onPressed: _zoomOut,
            child: Icon(Icons.zoom_out),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'recenterButton',
            onPressed: _recenter,
            child: Icon(Icons.my_location),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'themeButton',
            onPressed: () {
              setState(() {
                isMuted = true;
                _isNightMode = !_isNightMode;
                // Reset the mute state when switching modes
              });
              if (!_isNightMode && !_showBusStops) {
                _speakNavigationDirections(_currentInstruction);
              } else {
                flutterTts.stop(); // Stop speech
              }
            },
            child: Icon(_isNightMode ? Icons.wb_sunny : Icons.nightlight_round),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'sosButton',
            onPressed: () {
              // SOS button logic here
              _showSOSDialog();
            },
            backgroundColor: Colors.red,
            child: Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'audioButton',
            onPressed: () {
              setState(() {
                isMuted = !isMuted;
                if (isMuted) {
                  flutterTts.stop();
                } else {
                  _speakNavigationDirections(_currentInstruction);
                }
              });
            },
            child: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildMap() {
    LatLng initialTarget = _currentLocation.latitude == 0.0 &&
            _currentLocation.longitude == 0.0
        ? widget
            .startLocation // fallback to startLocation if current location is not available
        : _currentLocation;

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            _controller = controller;
            if (!_hasNavigationStarted) {
              _startBikeNavigation(); // Make sure this method is defined in your class
              _recenter();
              _hasNavigationStarted = true;
            }
            if (_isNightMode) {
              _controller?.setMapStyle(_darkMapStyle);
            }
          },
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: 18.0,
          ),
          markers:
              _markers, // This includes all markers, including current location
          mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
          // polylines: _polylines.values.toSet(),
          polylines: _polylines,
          onCameraMove: (CameraPosition position) {},
          myLocationButtonEnabled: false,
        ),
        Positioned(
          bottom: 50.0, // Adjust the positioning as needed
          left: 10.0,

          child: Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isSatelliteView = !_isSatelliteView;
                  });
                  _recenter();
                },
                child: Text(
                  _isSatelliteView ? 'Map View' : 'Satellite View',
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showBusStops = true;
                  });
                  _getBusStops();
                },
                child: Text('Get Transit Stops'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _recenter() async {
    final GoogleMapController controller = _controller!;
    double bearing = _calculateBearing(
      widget.startLocation.latitude,
      widget.startLocation.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    );

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        _currentLocation.latitude,
        _currentLocation.longitude,
      ),
      northeast: widget.destination,
    );

    double padding = 50.0;

    CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(
      bounds,
      padding,
    );

    controller.animateCamera(cameraUpdate);
    double tilt = _calculateTilt(bearing);
    Future.delayed(Duration(milliseconds: 500), () {
      double tilt = _calculateTilt(bearing);
      if (_isSatelliteView || _isNightMode) {
        // For satellite view, set tilt to 40.0
        tilt = 40.0;
      }
      controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: _currentLocation,
        zoom: 19.0,
        bearing: bearing,
        tilt: tilt,
      )));
    });
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("SOS"),
          content: Text("Do you want to call 911?"),
          actions: [
            TextButton(
              onPressed: () {
                // Handle "Yes" button click
                print("Calling 911...");
                Navigator.pop(context);
              },
              child: Text("Yes"),
            ),
            TextButton(
              onPressed: () {
                // Handle "No" button click
                Navigator.pop(context);
              },
              child: Text("No"),
            ),
          ],
        );
      },
    );
  }

  void _startBikeNavigation({LatLng? origin}) async {
    final currentOrigin = origin ?? widget.startLocation;
    final originString = '${currentOrigin.latitude},${currentOrigin.longitude}';
    if (!_isNightMode && !_showBusStops) {
      _speakNavigationDirections("Start navigation");
    }

    const apiKey = 'AIzaSyDkKbK_K-0WJuhGvvSbmSL5pEoCiBSWNqY'; //API Key
    // final source =
    //     '${widget.startLocation.latitude},${widget.startLocation.longitude}';
    final destination =
        '${widget.destination.latitude},${widget.destination.longitude}';
    final apiUrl = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$originString&destination=$destination&mode=bicycling&key=$apiKey';

    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final List<LatLng> points =
            _decodePolyline(data['routes'][0]['overview_polyline']['points']);
        Polyline polyline = Polyline(
          polylineId: PolylineId('bikePath'),
          color: Colors.blue,
          width: 5,
          points: points,
        );

        List<dynamic> stepsInstructions = data['routes'][0]['legs'][0]['steps'];
        globalNavigationSteps = _processSteps(stepsInstructions);
        print(globalNavigationSteps);
        currentStepIndex = 0; // Reset the index

        LatLngBounds polylineBounds = _getPolylineBounds(points);

        _controller!.animateCamera(
          CameraUpdate.newLatLngBounds(
            polylineBounds,
            50.0,
          ),
        );

        // setState(() {
        //   _polylines[PolylineId('bikePath')] = polyline;
        // });
        setState(() {
          _polylines = {..._polylines, polyline};
        });
      } else {
        print('Directions API request failed with status: ${data['status']}');
      }
    } else {
      print('Failed to fetch directions. Status code: ${response.statusCode}');
    }
  }

  String processInstructions(String instruction) {
    String processedInstruction = instruction
        .replaceAll("<b>", "")
        .replaceAll("</b>", "")
        .replaceAll("<div>.*?</div>",
            ""); // This line removes content between <div> and </div>
    return processedInstruction;
  }

  List<NavigationStep> _processSteps(List<dynamic> steps) {
    List<NavigationStep> navigationSteps = [];
    for (var step in steps) {
      String instruction = processInstructions(step['html_instructions']);
      print(instruction);
      LatLng endLocation = LatLng(
        step['end_location']['lat'],
        step['end_location']['lng'],
      );
      navigationSteps.add(NavigationStep(instruction, endLocation));
    }
    return navigationSteps;
  }

  void _getBusStops() async {
    const apiKey = 'AIzaSyDkKbK_K-0WJuhGvvSbmSL5pEoCiBSWNqY';
    final apiUrl = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${widget.startLocation.latitude},${widget.startLocation.longitude}&'
        'destination=${widget.destination.latitude},${widget.destination.longitude}&'
        'mode=transit&alternatives=true&key=$apiKey';

    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['status'] == 'OK') {
        _displayBusStops(data['routes'][0]['legs'][0]['steps']);
      } else {
        print('Transit API request failed with status: ${data['status']}');
      }
    } else {
      print(
          'Failed to fetch transit information. Status code: ${response.statusCode}');
    }
  }

  void _displayBusStops(List<dynamic> steps) {
    Set<Marker> busStopMarkers = {};
    int transitStopsCount = 0; // Counter for transit stops

    for (var step in steps) {
      if (step['transit_details'] != null) {
        final LatLng busStopLocation = LatLng(
          step['start_location']['lat'],
          step['start_location']['lng'],
        );

        Marker busStopMarker = Marker(
          markerId: MarkerId('busStop-${busStopLocation.hashCode}'),
          position: busStopLocation,
          infoWindow: InfoWindow(title: 'Public Transportation'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        );

        busStopMarkers.add(busStopMarker);
        transitStopsCount++;
        if (transitStopsCount >= 3) {
          break;
        }
      }
    }

    setState(() {
      _busStopMarkers = busStopMarkers;
    });
  }

  LatLngBounds _getPolylineBounds(List<LatLng> points) {
    double minLat = double.infinity;
    double minLng = double.infinity;
    double maxLat = double.negativeInfinity;
    double maxLng = double.negativeInfinity;

    for (LatLng point in points) {
      double lat = point.latitude;
      double lng = point.longitude;

      minLat = min(minLat, lat);
      minLng = min(minLng, lng);
      maxLat = max(maxLat, lat);
      maxLng = max(maxLng, lng);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng((lat / 1E5), (lng / 1E5)));
    }
    return points;
  }

  double _calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    double startLat = _degreesToRadians(lat1);
    double startLong = _degreesToRadians(lon1);
    double endLat = _degreesToRadians(lat2);
    double endLong = _degreesToRadians(lon2);

    double dLong = endLong - startLong;

    double dPhi =
        log(tan(endLat / 2.0 + pi / 4.0) / tan(startLat / 2.0 + pi / 4.0));

    double bearing = atan2(dLong, dPhi);

    bearing = _radiansToDegrees(bearing);
    bearing = (bearing + 360.0) % 360.0;

    return bearing;
  }

  double _radiansToDegrees(double radians) {
    return radians * (180.0 / pi);
  }

  double _calculateTilt(double bearing) {
    const double maxTilt = 70.0;
    return _clamp(bearing.abs(), 0.0, maxTilt);
  }

  double _clamp(double value, double min, double max) {
    return value.clamp(min, max);
  }

  void _zoomIn() {
    _controller?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _controller?.animateCamera(CameraUpdate.zoomOut());
  }

  void _speakNavigationDirections(String message) async {
    //for text to speech
    if (!isMuted) {
      await flutterTts.speak(message);
    }
  }
}
