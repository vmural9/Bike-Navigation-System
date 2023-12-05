import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_place/google_place.dart';
import 'package:fsp/PreviewMap.dart';
import 'package:permission_handler/permission_handler.dart';

class NavigationPage extends StatefulWidget {
  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  // String _selectedItem = "Long and Straight Roads"; // Initialize with a default value

  final _startSearchFieldController = TextEditingController();
  final _endSearchFieldController = TextEditingController();

  String _startLocation = "";
  DetailsResult? startPosition;
  DetailsResult? endPosition;

  late FocusNode startFocusNode;
  late FocusNode endFocusNode;

  late GooglePlace googlePlace;
  List<AutocompletePrediction> predictions = [];

  bool isLoading = false;
  bool isMarkerClicked = false;

  void autoCompleteSearch(String value) async {
    var result = await googlePlace.autocomplete.get(value);
    if (result != null && result.predictions != null && mounted) {
      setState(() {
        predictions = result.predictions!;
      });
    } else {
      print("Response ERROR!");
    }
  }

  @override
  void initState() {
    super.initState();
    String apiKey = 'AIzaSyDkKbK_K-0WJuhGvvSbmSL5pEoCiBSWNqY';
    googlePlace = GooglePlace(apiKey);

    startFocusNode = FocusNode();
    endFocusNode = FocusNode();
  }

  void getCurrentLocation() async {
    try {
      setState(() {
        isLoading = true; // Show loading feedback
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _startLocation = "${position.latitude},${position.longitude}";
        startPosition = DetailsResult(
          name: "Current Location",
          geometry: Geometry(
            location: Location(
              lat: position.latitude,
              lng: position.longitude,
            ),
          ),
        );
        _startSearchFieldController.text = "Current Location";
        isLoading = false; // Hide feedback
        isMarkerClicked = false; // Reset marker clicked state
      });
    } catch (e) {
      setState(() {
        isLoading = false; // Hides loading feedback on error
      });
      print("Error getting current location: $e");
    }
  }

  @override
  void dispose() {
    super.dispose();
    startFocusNode.dispose();
    endFocusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Navigation Page"),
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isMarkerClicked = true; //marker clicked state
                  });
                  getCurrentLocation();
                },
                child: Stack(
                  alignment: Alignment.centerLeft, //Alignment
                  children: [
                    TextField(
                      controller: _startSearchFieldController,
                      autofocus: false,
                      focusNode: startFocusNode,
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Start Location",
                        filled: _startSearchFieldController.text.isNotEmpty &&
                            startPosition != null,
                        suffixIcon: isMarkerClicked
                            ? SizedBox(
                                width: 24.0, // circular icon width
                                height: 24.0, // circular icon height
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black),
                                ),
                              )
                            : _startSearchFieldController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      setState(() {
                                        predictions = [];
                                        _startSearchFieldController.clear();
                                        startPosition = null;
                                      });
                                    },
                                    icon: Icon(Icons.clear_outlined),
                                  )
                                : null,
                      ),
                      onChanged: (text) {
                        _startLocation = text;
                        if (text.isNotEmpty && text.length > 3) {
                          autoCompleteSearch(text);
                        } else {
                          setState(() {
                            predictions = [];
                            startPosition = null;
                          });
                        }
                      },
                    ),
                    Positioned(
                      right: 50.0,
                      child: Icon(Icons.location_on, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _endSearchFieldController,
                autofocus: false,
                focusNode: endFocusNode,
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                enabled: _startSearchFieldController.text.isNotEmpty &&
                    startPosition != null,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "End Location",
                  filled: _endSearchFieldController.text.isNotEmpty,
                  suffixIcon: _endSearchFieldController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              predictions = [];
                              _endSearchFieldController.clear();
                              endPosition = null;
                            });
                          },
                          icon: Icon(Icons.clear_outlined),
                        )
                      : null,
                ),
                onChanged: (text) {
                  _startLocation = text;
                  if (text.isNotEmpty && text.length > 3) {
                    autoCompleteSearch(text);
                  } else {
                    setState(() {
                      predictions = [];
                    });
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  print(startPosition);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PreviewScreen(
                        startPosition: startPosition,
                        endPosition: endPosition,
                      ),
                    ),
                  );
                },
                child: Text("Preview"),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              itemCount: predictions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      Icons.pin_drop,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    predictions[index].description.toString(),
                  ),
                  onTap: () async {
                    final placeId = predictions[index].placeId!;
                    final details = await googlePlace.details.get(placeId);
                    if (details != null && details.result != null && mounted) {
                      if (startFocusNode.hasFocus) {
                        setState(() {
                          startPosition = details.result;
                          _startSearchFieldController.text =
                              details.result!.name!;
                          predictions = [];
                        });
                      } else {
                        setState(() {
                          endPosition = details.result;
                          _endSearchFieldController.text =
                              details.result!.name!;
                          predictions = [];
                        });
                      }
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
