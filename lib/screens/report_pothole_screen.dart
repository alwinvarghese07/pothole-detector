import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'dart:io';
import 'pothole.dart';

class ReportPotholeScreen extends StatefulWidget {
  @override
  _ReportPotholeScreenState createState() => _ReportPotholeScreenState();
}

class _ReportPotholeScreenState extends State<ReportPotholeScreen> {
  String _locationText = 'Fetching location...';
  double? _latitude;
  double? _longitude;
  String? _hazardType = 'Pothole';
  final TextEditingController _notesController = TextEditingController();
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final Location _locationService = Location();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    setState(() => _locationText = 'Fetching location...');
    try {
      if (!await _locationService.serviceEnabled() &&
          !await _locationService.requestService()) {
        setState(() => _locationText = 'Location services disabled. Please enable.');
        return;
      }

      PermissionStatus permission = await _locationService.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _locationService.requestPermission();
        if (permission != PermissionStatus.granted) {
          setState(() => _locationText = 'Location permission denied.');
          return;
        }
      }

      await _locationService.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000,
      );

      LocationData locationData = await _locationService.getLocation();
      print('Report screen - Lat: ${locationData.latitude}, Lon: ${locationData.longitude}, Accuracy: ${locationData.accuracy}m');

      setState(() {
        _latitude = locationData.latitude;
        _longitude = locationData.longitude;
        _locationText = 'Lat: ${_latitude?.toStringAsFixed(4)}, Lon: ${_longitude?.toStringAsFixed(4)}';
        if (_latitude != null && _longitude != null) {
          _mapController.move(latlong.LatLng(_latitude!, _longitude!), 15.0);
        }
      });
    } catch (e) {
      setState(() => _locationText = 'Error: $e');
      print('Error fetching location: $e');
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _submitReport() {
    if (_latitude != null && _longitude != null) {
      final pothole = Pothole(
        latitude: _latitude!,
        longitude: _longitude!,
        type: _hazardType!,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        imagePath: _image?.path,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hazard reported at $_locationText')),
      );
      Navigator.pop(context, pothole);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location not available. Please refresh.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report Hazard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(_locationText),
              SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: latlong.LatLng(_latitude ?? 0.0, _longitude ?? 0.0),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.pothole_reporter',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_latitude != null && _longitude != null)
                          Marker(
                            point: latlong.LatLng(_latitude!, _longitude!),
                            width: 40,
                            height: 40,
                            child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _getLocation,
                child: Text('Refresh Location'),
              ),
              SizedBox(height: 20),
              Text('Hazard Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              DropdownButton<String>(
                value: _hazardType,
                onChanged: (String? newValue) {
                  setState(() {
                    _hazardType = newValue;
                  });
                },
                items: <String>[
                  'Pothole',
                  'Flooded Roads',
                  'Fallen Trees',
                  'Construction Works',
                  'Landslide',
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              Text('Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Add any additional details...',
                ),
                maxLines: 3,
              ),
              SizedBox(height: 20),
              Text('Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              _image == null ? Text('No photo selected.') : Image.file(_image!, height: 150),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Take Photo'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text('Submit', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}