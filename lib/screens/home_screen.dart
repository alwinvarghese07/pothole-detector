import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'report_pothole_screen.dart';
import 'pothole.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double? _latitude;
  double? _longitude;
  final Location _locationService = Location();
  final MapController _mapController = MapController();
  List<Pothole> _potholes = [];
  List<latlong.LatLng> _pathPoints = [];
  double? _routeDistance; // Distance in kilometers
  double? _routeDuration; // Duration in minutes

  // Replace with your actual OpenRouteService API key
  final String _apiKey =
      '5b3ce3597851110001cf62484ec9e16c2fac49709a84a418bf703936';

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      if (!await _locationService.serviceEnabled() &&
          !await _locationService.requestService()) {
        print('Location services disabled.');
        return;
      }

      PermissionStatus permission = await _locationService.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _locationService.requestPermission();
        if (permission != PermissionStatus.granted) {
          print('Location permission denied.');
          return;
        }
      }

      await _locationService.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000,
      );

      LocationData locationData = await _locationService.getLocation();
      print(
          'Home screen - Lat: ${locationData.latitude}, Lon: ${locationData.longitude}, Accuracy: ${locationData.accuracy}m');

      setState(() {
        _latitude = locationData.latitude;
        _longitude = locationData.longitude;
        if (_latitude != null && _longitude != null) {
          _mapController.move(latlong.LatLng(_latitude!, _longitude!), 15.0);
        }
      });
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  void _navigateToReportScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReportPotholeScreen()),
    );
    if (result != null && result is Pothole) {
      setState(() {
        _potholes.add(result);
        print(
            'Added hazard at Lat: ${result.latitude}, Lon: ${result.longitude}, Type: ${result.type}');
      });
    }
  }

  Widget _getMarkerIcon(String type) {
    switch (type) {
      case 'Pothole':
        return Text('🕳️', style: TextStyle(fontSize: 40, color: Colors.brown));
      case 'Flooded Roads':
        return Text('🌊', style: TextStyle(fontSize: 40, color: Colors.blue));
      case 'Fallen Trees':
        return Text('🌳', style: TextStyle(fontSize: 40, color: Colors.green));
      case 'Construction Works':
        return Text('🚧', style: TextStyle(fontSize: 40, color: Colors.orange));
      case 'Landslide':
        return Text('⛰️', style: TextStyle(fontSize: 40, color: Colors.grey));
      default:
        return Text('⚠️', style: TextStyle(fontSize: 40, color: Colors.black));
    }
  }

  LatLngBounds _calculateBounds(List<latlong.LatLng> points) {
    if (points.isEmpty)
      return LatLngBounds(latlong.LatLng(0, 0), latlong.LatLng(0, 0));
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLon = points[0].longitude;
    double maxLon = points[0].longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    return LatLngBounds(
      latlong.LatLng(minLat, minLon),
      latlong.LatLng(maxLat, maxLon),
    );
  }

  Future<Map<String, dynamic>> _fetchRoute(
      double fromLat, double fromLon, double toLat, double toLon) async {
    final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car/geojson');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'coordinates': [
            [fromLon, fromLat],
            [toLon, toLat],
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coordinates =
            data['features'][0]['geometry']['coordinates'] as List;
        final routePoints = coordinates
            .map((coord) => latlong.LatLng(coord[1], coord[0]))
            .toList();
        final summary = data['features'][0]['properties']['summary'];
        final distance =
            summary['distance'] / 1000; // Convert meters to kilometers
        final duration = summary['duration'] / 60; // Convert seconds to minutes
        print(
            'Route fetched successfully: ${routePoints.length} points, Distance: $distance km, Duration: $duration min');
        return {
          'points': routePoints,
          'distance': distance,
          'duration': duration,
        };
      } else {
        print(
            'Error fetching route: ${response.statusCode} - ${response.body}');
        return {
          'points': [
            latlong.LatLng(fromLat, fromLon),
            latlong.LatLng(toLat, toLon)
          ],
          'distance': 0.0,
          'duration': 0.0,
        };
      }
    } catch (e) {
      print('Exception while fetching route: $e');
      return {
        'points': [
          latlong.LatLng(fromLat, fromLon),
          latlong.LatLng(toLat, toLon)
        ],
        'distance': 0.0,
        'duration': 0.0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPlaceSuggestions(
      String query) async {
    final url = Uri.parse(
        'https://api.openrouteservice.org/geocode/autocomplete?api_key=$_apiKey&text=$query');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;
        return features.map((feature) {
          final coords = feature['geometry']['coordinates'];
          return {
            'name': feature['properties']['label'],
            'latitude': coords[1],
            'longitude': coords[0],
          };
        }).toList();
      } else {
        print(
            'Error fetching suggestions: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception while fetching suggestions: $e');
      return [];
    }
  }

  String _formatDuration(double minutes) {
    final hours = (minutes / 60).floor();
    final remainingMinutes = (minutes % 60).round();
    if (hours > 0) {
      return '${hours}h ${remainingMinutes}m';
    } else {
      return '${remainingMinutes}m';
    }
  }

  void _showPathDialog() {
    final fromController = TextEditingController();
    final toController = TextEditingController();
    latlong.LatLng? fromCoords;
    latlong.LatLng? toCoords;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Set Path'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) return [];
                    final suggestions =
                        await _fetchPlaceSuggestions(textEditingValue.text);
                    return suggestions;
                  },
                  displayStringForOption: (option) => option['name'],
                  onSelected: (option) {
                    fromController.text = option['name'];
                    fromCoords =
                        latlong.LatLng(option['latitude'], option['longitude']);
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                    fromController.text = controller.text;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(labelText: 'From Place'),
                    );
                  },
                ),
                SizedBox(height: 16),
                Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) return [];
                    final suggestions =
                        await _fetchPlaceSuggestions(textEditingValue.text);
                    return suggestions;
                  },
                  displayStringForOption: (option) => option['name'],
                  onSelected: (option) {
                    toController.text = option['name'];
                    toCoords =
                        latlong.LatLng(option['latitude'], option['longitude']);
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                    toController.text = controller.text;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(labelText: 'To Place'),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (fromCoords != null && toCoords != null) {
                  final routeData = await _fetchRoute(
                    fromCoords!.latitude,
                    fromCoords!.longitude,
                    toCoords!.latitude,
                    toCoords!.longitude,
                  );
                  setState(() {
                    _pathPoints = routeData['points'];
                    _routeDistance = routeData['distance'];
                    _routeDuration = routeData['duration'];
                    final bounds = _calculateBounds(_pathPoints);
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: bounds,
                        padding: EdgeInsets.all(50.0),
                      ),
                    );
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Please select both start and end places')),
                  );
                }
              },
              child: Text('Show Path'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _getLocation,
            tooltip: 'Refresh Location',
          ),
          IconButton(
            icon: Icon(Icons.linear_scale),
            onPressed: _showPathDialog,
            tooltip: 'Set Path',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  latlong.LatLng(_latitude ?? 0.0, _longitude ?? 0.0),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.pothole_reporter',
              ),
              if (_pathPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _pathPoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_latitude != null && _longitude != null)
                    Marker(
                      point: latlong.LatLng(_latitude!, _longitude!),
                      width: 40,
                      height: 40,
                      child:
                          Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                  ..._potholes.map(
                    (pothole) => Marker(
                      point:
                          latlong.LatLng(pothole.latitude, pothole.longitude),
                      width: 40,
                      height: 40,
                      child: _getMarkerIcon(pothole.type),
                    ),
                  ),
                  if (_pathPoints.isNotEmpty)
                    Marker(
                      point: _pathPoints.first,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  if (_pathPoints.isNotEmpty)
                    Marker(
                      point: _pathPoints.last,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            top: 16,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('🕳️', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text('Pothole', style: TextStyle(fontSize: 14))
                  ]),
                  SizedBox(height: 8),
                  Row(children: [
                    Text('🌊', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text('Flooded Roads', style: TextStyle(fontSize: 14))
                  ]),
                  SizedBox(height: 8),
                  Row(children: [
                    Text('🌳', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text('Fallen Trees', style: TextStyle(fontSize: 14))
                  ]),
                  SizedBox(height: 8),
                  Row(children: [
                    Text('🚧', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text('Construction', style: TextStyle(fontSize: 14))
                  ]),
                  SizedBox(height: 8),
                  Row(children: [
                    Text('⛰️', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text('Landslide', style: TextStyle(fontSize: 14))
                  ]),
                ],
              ),
            ),
          ),
          // Enhanced distance and time block with more space and aesthetics
          if (_routeDistance != null && _routeDuration != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 90, // Increased from 70 to 90 for more space
              child: Container(
                padding: EdgeInsets.symmetric(
                    vertical: 12, horizontal: 16), // More padding
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95), // Slightly more opaque
                  borderRadius: BorderRadius.circular(12), // Softer corners
                  border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1), // Subtle border
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Distance: ${_routeDistance!.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800], // Darker blue for contrast
                      ),
                    ),
                    SizedBox(width: 20), // Slightly more spacing
                    Text(
                      'Time: ${_formatDuration(_routeDuration!)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _navigateToReportScreen,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: const Color.fromARGB(255, 255, 44, 44),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Report Hazard', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
