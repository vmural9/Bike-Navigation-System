import 'package:flutter/material.dart';
import 'package:fsp/NavigationPage.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:fsp/PreviewMap.dart';
import 'package:google_place/google_place.dart';

Future<List<SavedLocation>> loadLocationsFromLocalFile() async {
  final file = await _getLocalFile();
  print("getting json information");

  if (!file.existsSync()) {
    await file.create(recursive: true);
    await file.writeAsString('[]'); // Initialize with empty JSON array
  }

  String data = await file.readAsString();
  final List<dynamic> jsonResult = json.decode(data);
  print(jsonResult.map((item) => SavedLocation.fromJson(item)).toList());
  return jsonResult.map((item) => SavedLocation.fromJson(item)).toList();
}

Future<File> _getLocalFile() async {
  print("trying to access the json file.");
  final directory = await getApplicationDocumentsDirectory();
  return File('${directory.path}/my_data.json');
}

String toCamelCase(String text) {
  return text
      .split(' ')
      .map((word) => word.isEmpty
          ? ''
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}

//Weather Data model
class WeatherInfo {
  final String description;
  final double temperature;

  WeatherInfo({required this.description, required this.temperature});

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      description: json['weather'][0]['description'],
      temperature: json['main']['temp'],
    );
  }
}

//Fetching Weather data from OpenWeatherMap

//Actual Widget
class WeatherWidget extends StatelessWidget {
  final WeatherInfo weatherInfo;

  const WeatherWidget({Key? key, required this.weatherInfo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topLeft,
      padding: EdgeInsets.all(0),
      // decoration: BoxDecoration(
      //   color: Colors.blueGrey.withOpacity(0),
      //   borderRadius: BorderRadius.circular(8),
      // ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons
                .wb_sunny, // You may want to choose an icon based on the actual weather conditions
            color: Colors.white,
          ),
          SizedBox(width: 8),
          Text(
            '${weatherInfo.temperature.toStringAsFixed(1)}°C',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 4),
          Text(
            toCamelCase(weatherInfo.description),
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'BikePath Navigator - Main Page',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  void getNext() {
    notifyListeners();
  }
}

class MyHomePage extends StatelessWidget {
  Future<void> _showSOSDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
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
                //Yes
                print("Calling 911");
                Navigator.of(context).pop();
              },
              child: Text('Yes'),
            ),
            TextButton(
              onPressed: () {
                //No
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

  Future<WeatherInfo> getWeather() async {
    const requestUrl =
        'https://api.openweathermap.org/data/2.5/weather?lat=41.8755616&lon=-87.6244212&appid=9d25c0681ac0e881996d3459e779841d&units=metric';

    final response = await http.get(Uri.parse(requestUrl));

    print(response.statusCode);

    if (response.statusCode == 200) {
      return WeatherInfo.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load weather data');
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    Future<List<SavedLocation>>? locationsFuture;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/bg.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            //transparent black frame.
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 20, vertical: 40), // Adjust padding as needed
              margin:
                  EdgeInsets.all(10), // Optional: margin around the container
              decoration: BoxDecoration(
                color: Colors.black54
                    .withOpacity(0.88), // Semi-transparent black box
                borderRadius:
                    BorderRadius.circular(15), // Optional: rounded corners
                border: Border.all(
                  color: Colors.black54.withOpacity(0.2), // Set border color
                  width: 6.0, // Set border width
                ),
              ),
              child: Column(
                //Main page content.
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FutureBuilder<WeatherInfo>(
                    future: getWeather(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        print("Weather Report failed: ${snapshot.error}");
                        return Text('Weather data unavailable');
                      } else if (snapshot.hasData) {
                        print("Weather Data got");
                        print(snapshot.data!);
                        return WeatherWidget(weatherInfo: snapshot.data!);
                      } else {
                        return Container(); // Empty container for no data
                      }
                    },
                  ),
                  SizedBox(
                      //Space between
                      height: 90),
                  Align(
                    //Title
                    alignment: Alignment.topLeft,
                    child: RichText(
                      textAlign: TextAlign.left,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "BikePath\n", // First line
                            style: GoogleFonts.roboto(
                              textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 45,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextSpan(
                            text: "NAVIGATOR", // Second line
                            style: GoogleFonts.roboto(
                              textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 45,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                      //Space between
                      height:
                          10), // Add some spacing between title and subtitle
                  Align(
                    //SUBTITLE
                    alignment: Alignment.topLeft,
                    child: Text(
                      "Navigate Your Ride, Discover Your Path – \nReal-time, Biker-Centric Navigation at Your Fingertips.",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Color.fromARGB(255, 152, 152,
                            152), // Slightly lighter color for subtitle
                        fontSize: 14.0, // Subtitle font size
                      ),
                    ),
                  ),

                  SizedBox(height: 50),

                  Align(
                    //SUBTITLE
                    alignment: Alignment.topLeft,
                    child: Text(
                      "Saved Routes",
                      textAlign: TextAlign.left,
                      style: GoogleFonts.roboto(
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 5),

                  Container(
                    height: 300,
                    child: MyWidget(),

                    // Your custom widget with the list
                  ),

                  SizedBox(height: 20),

                  ElevatedButton(
                    //GET DIRECTIONS button
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NavigationPage()),
                      );
                      print("Moving to Navigation page");
                    },
                    child: Text(
                      "Plan a New Route",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color.fromARGB(255, 39, 39,
                            39), // Slightly lighter color for subtitle
                        fontSize: 16.0, // Subtitle font size
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 60.0,
            right: 20.0,
            child: ElevatedButton(
              onPressed: () {
                _showSOSDialog(context); // calling SOS function
              },
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(35),
                primary: Colors.red,
              ),
              child: Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 25 : 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SavedLocation {
  //Structure variable for saved routes.
  String name;
  String startlocation;
  String endlocation;
  String time;
  String distance;
  double startlat;
  double startlng;
  double endlat;
  double endlng;

  SavedLocation(
      {required this.name,
      required this.startlocation,
      required this.endlocation,
      required this.time,
      required this.distance,
      required this.startlat,
      required this.startlng,
      required this.endlat,
      required this.endlng});

  // Add a method to parse JSON data
  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      name: json['name'],
      startlocation: json['startlocation'],
      endlocation: json['endlocation'],
      time: json['time'],
      distance: json['distance'],
      startlat: json['startlat'],
      startlng: json['startlng'],
      endlat: json['endlat'],
      endlng: json['endlng'],
    );
  }
}

class SavedLocationsList extends StatelessWidget {
  final List<SavedLocation> locations; // Pass the list of locations

  SavedLocationsList({Key? key, required this.locations}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final location = locations[index];
        return InkWell(
          onTap: () {
            final startPosition = DetailsResult(
              name:
                  location.startlocation, // Or "Current Location" if you prefer
              geometry: Geometry(
                location: Location(
                  lat: location.startlat,
                  lng: location.startlng,
                ),
              ),
            );

            final endPosition = DetailsResult(
              name: location.endlocation,
              geometry: Geometry(
                location: Location(
                  lat: location.endlat,
                  lng: location.endlng,
                ),
              ),
            );

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
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 0),
            decoration: BoxDecoration(
              color: Color.fromARGB(179, 244, 244, 244),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 3,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(location.name,
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        location.startlocation,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_forward), // Arrow icon
                    Flexible(
                      child: Text(
                        location.endlocation,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text("${location.time} | ${location.distance} "),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late Future<List<SavedLocation>> locationsFuture;

  @override
  void initState() {
    super.initState();
    locationsFuture = loadLocationsFromLocalFile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SavedLocation>>(
      future: locationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text('No locations saved.');
        } else {
          return Expanded(
            child: SavedLocationsList(locations: snapshot.data!),
          );
        }
      },
    );
  }
}
