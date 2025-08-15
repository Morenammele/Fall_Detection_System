import 'package:difds/components/google_drive_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FallDetectionApp());
}

class FallDetectionApp extends StatelessWidget {
  const FallDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Detection',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  static const LatLng _hardcodedLocation = LatLng(-29.305166, 27.484333);

  final List<Widget> _screens = [
    const HomeTab(),
    const HistoryTab(),
    const MediaTab(), // Replaced SettingsTab with MediaTab
    const NotificationsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Detection'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          _pageController.jumpToPage(index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: 'Media',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const LatLng _hardcodedLocation = LatLng(-29.305166, 27.484333);

  LatLng? _fallLocation = _hardcodedLocation;
  String _statusText = 'No recent falls detected';
  Color _statusColor = Colors.green;
  Map<String, dynamic>? _latestEvent;
  bool _isLoading = true;

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref(
    'fall_events',
  );

  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _listenForNewFalls();
    _loadLatestFall();
  }

  void _listenForNewFalls() {
    _databaseRef.orderByChild('timestamp').limitToLast(1).onChildAdded.listen((
      event,
    ) async {
      await _playAlertSound();

      if (mounted) {
        setState(() {
          final eventData = event.snapshot.value as Map<dynamic, dynamic>;
          _latestEvent = Map<String, dynamic>.from(eventData);
          _fallLocation = _hardcodedLocation; // use hardcoded location
          _statusText =
              'FALL DETECTED: ${_latestEvent!['patient'] ?? 'Unknown'}';
          _statusColor = Colors.red;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadLatestFall() async {
    try {
      final snapshot =
          await _databaseRef.orderByChild('timestamp').limitToLast(1).get();

      if (snapshot.exists && mounted) {
        final eventsMap = snapshot.value as Map<dynamic, dynamic>;
        final eventKey = eventsMap.keys.first;
        _latestEvent = Map<String, dynamic>.from(eventsMap[eventKey]);

        setState(() {
          _fallLocation = _hardcodedLocation; // use hardcoded location
          _statusText =
              'FALL DETECTED: ${_latestEvent!['patient'] ?? 'Unknown'}';
          _statusColor = Colors.red;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _fallLocation = _hardcodedLocation;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _fallLocation = _hardcodedLocation;
        });
      }
      debugPrint('Error loading fall data: $e');
    }
  }

  Future<void> _playAlertSound() async {
    if (!isPlaying) {
      FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
      setState(() {
        isPlaying = true;
      });
    }
  }

  Future<void> _stopAlertSound() async {
    if (isPlaying) {
      FlutterRingtonePlayer().stop();
      setState(() {
        isPlaying = false;
      });
    }
  }

  @override
  void dispose() {
    FlutterRingtonePlayer().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: _statusColor.withOpacity(0.2),
          child: Row(
            children: [
              Icon(Icons.warning, color: _statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ),
              Text(
                '${_fallLocation?.latitude.toStringAsFixed(4)}, ${_fallLocation?.longitude.toStringAsFixed(4)}',
                style: TextStyle(color: _statusColor),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _playAlertSound,
                icon: const Icon(Icons.volume_up),
                label: const Text('Play Alert'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _stopAlertSound,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Alert'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _fallLocation!,
              initialZoom: 16.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.difds',
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _fallLocation!,
                    width: 60,
                    height: 60,
                    child: Icon(
                      Icons.location_pin,
                      color: _statusColor,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final databaseRef = FirebaseDatabase.instance.ref('fall_events');
    final dateFormat = DateFormat('MMM dd, hh:mm a');

    return StreamBuilder<DatabaseEvent>(
      stream: databaseRef.orderByChild('timestamp').onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final eventsMap =
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;

        if (eventsMap == null || eventsMap.isEmpty) {
          return const Center(child: Text('No fall events recorded'));
        }

        final events =
            eventsMap.entries.map((entry) {
                final eventData = Map<String, dynamic>.from(entry.value as Map)
                  ..putIfAbsent('timestamp', () => '');
                return {'id': entry.key as String, 'data': eventData};
              }).toList()
              ..sort((a, b) {
                final timestampA =
                    (a['data'] as Map<String, dynamic>)['timestamp'] as String;
                final timestampB =
                    (b['data'] as Map<String, dynamic>)['timestamp'] as String;
                return timestampB.compareTo(timestampA);
              });

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final Map<String, dynamic> event =
                events[index]['data'] as Map<String, dynamic>;
            final timestamp = DateTime.parse(event['timestamp'] as String);
            final location = LatLng(
              event['latitude']?.toDouble() ?? 0,
              event['longitude']?.toDouble() ?? 0,
            );

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red[100],
                  child: Icon(Icons.warning, color: Colors.red),
                ),
                title: Text(
                  event['patient'] ?? 'Fall Event',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateFormat.format(timestamp)),
                    Text(
                      '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                    ),
                    Text('Confidence: ${event['confidence']}%'),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => MapViewScreen(
                            location: location,
                            eventData: event,
                          ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class MapViewScreen extends StatelessWidget {
  final LatLng location;
  final Map<String, dynamic> eventData;

  static const LatLng _hardcodedLocation = LatLng(-29.305166, 27.484333);

  const MapViewScreen({
    super.key,
    required this.location,
    required this.eventData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fall Location')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _hardcodedLocation,
          initialZoom: 17.0,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.difds',
            subdomains: ['a', 'b', 'c'],
            tileSize: 256,
            maxZoom: 19,
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _hardcodedLocation,
                width: 80,
                height: 80,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 50,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MediaTab extends StatefulWidget {
  const MediaTab({super.key});

  @override
  State<MediaTab> createState() => _MediaTabState();
}

class _MediaTabState extends State<MediaTab> {
  final GoogleDriveService _driveService = GoogleDriveService();
  List<Map<String, dynamic>> _mediaItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadMedia();
  }

  Future<void> _initializeAndLoadMedia() async {
    await _driveService.initialize();
    await _loadMedia();
  }

  Future<void> _loadMedia() async {
    try {
      final databaseRef = FirebaseDatabase.instance.ref('fall_events');
      final snapshot = await databaseRef.get();

      if (snapshot.exists) {
        final eventsMap = snapshot.value as Map<dynamic, dynamic>;
        final items = await Future.wait(
          eventsMap.entries.map((entry) async {
            final eventData = Map<String, dynamic>.from(entry.value);
            final videoLink = eventData['video_link'] as String?;
            String? downloadUrl = videoLink;

            if (videoLink?.contains('drive.google.com') ?? false) {
              final fileId = RegExp(
                r'/file/d/([a-zA-Z0-9_-]+)',
              ).firstMatch(videoLink!)?.group(1);

              if (fileId != null) {
                downloadUrl = await _driveService.getVideoDownloadUrl(fileId);
              }
            }

            return {
              'download_url': downloadUrl,
              'timestamp': eventData['timestamp'],
              'patient': eventData['patient'] ?? 'Unknown',
            };
          }),
        );

        setState(() {
          _mediaItems =
              items.where((item) => item['download_url'] != null).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading media: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_mediaItems.isEmpty) {
      return const Center(child: Text('No media available'));
    }

    return ListView.builder(
      itemCount: _mediaItems.length,
      itemBuilder: (context, index) {
        final media = _mediaItems[index];
        final timestamp = DateTime.parse(media['timestamp'] as String);

        return ListTile(
          leading: const Icon(Icons.video_library),
          title: Text(media['patient'] as String),
          subtitle: Text(
            DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp),
          ),
          trailing: const Icon(Icons.play_arrow),
          onTap: () => _launchVideo(media['download_url'] as String),
        );
      },
    );
  }

  Future<void> _launchVideo(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch video URL';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not play video: $e')));
    }
  }
}

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Notifications'));
  }
}
