import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'login_page.dart';
import 'firebase_config.dart';
import 'package:firebase_storage/firebase_storage.dart';

final _player = AudioPlayer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const ListeningApp());
}

class ListeningApp extends StatelessWidget {
  const ListeningApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'muse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueGrey[900],
        scaffoldBackgroundColor: Colors.blueGrey[800],
        hintColor: Colors.blueGrey[100],
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoggedIn = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<String> _songs = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('muse'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              _uploadSong();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _logout();
            },
          ),
        ],
      ),
      body: _buildMainInterface(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  void _logout() async {
    await _auth.signOut();
    setState(() {
      _isLoggedIn = false;
    });
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }


  Widget _buildMainInterface() {
    return Column(
      children: [
        const ListTile(
          title: Text("Songs"),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _songs.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SongPage(songUrl: _songs[index]),
                    ),
                  );
                },
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    title: Text("Song ${index + 1}"),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: () {
              _player.seek(Duration.zero);
            },
          ),
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final playerState = snapshot.data;
              final processingState = playerState?.processingState;
              if (processingState == ProcessingState.loading ||
                  processingState == ProcessingState.buffering) {
                return const CircularProgressIndicator();
              } else if (processingState == ProcessingState.ready) {
                return IconButton(
                  icon: Icon(
                    playerState!.playing ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: () {
                    if (playerState.playing) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                );
              } else {
                return const Icon(Icons.play_arrow);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: () {
              // TODO: Implement skip to next song functionality
            },
          ),
        ],
      ),
    );
  }

void _uploadSong() async {
  try {
    // Select the file
   FilePickerResult? result = await FilePicker.platform.pickFiles(withReadStream: false);

    if (result != null) {
      PlatformFile platformFile = result.files.first;

      if (platformFile.bytes != null) {
        // Create a reference to the location you want to upload to in Firebase Storage
        FirebaseStorage storage = FirebaseStorage.instance;
        Reference ref = storage.ref().child("gs://yourfile address");

        // Upload the file to Firebase Storage
        UploadTask uploadTask = ref.putData(platformFile.bytes!);
           await uploadTask.whenComplete(() {
      print('Upload complete!');
      });
      
        
        // Monitor the upload task for status changes
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          print('Task state: ${snapshot.state}');
          print('Progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100} %');
        }, onError: (e) {
          // Handle any errors
          print(uploadTask.snapshot);
        
          if (e.code == 'permission-denied') {
            print('User does not have permission to upload to this reference.');
          }
        });

        // Use the .whenComplete() method to get a callback when the upload is complete
        await uploadTask.whenComplete(() {
          print('Upload complete!');
        });

        // Get the download URL for the uploaded file
        String? downloadURL = await ref.getDownloadURL();

        // Add the download URL to your _songs list
        setState(() {
          _songs.add(downloadURL);
        });
            } else {
        print('No bytes available in the selected file.');
      }
    } else {
      // User canceled the picker
      print('No file selected.');
    }
  } catch (e) {
    // Handle any errors
    print('An error occurred while uploading the file: $e');
  }
}
}

class SongPage extends StatefulWidget {
  final String songUrl;

  const SongPage({Key? key, required this.songUrl}) : super(key: key);

  @override
  _SongPageState createState() => _SongPageState();
}

class _SongPageState extends State<SongPage> {
late AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    print('Song URL: ${widget.songUrl}');
    await _player.setUrl(widget.songUrl);
    _player.play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Song'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Now Playing'),
            const SizedBox(height: 20),
            StreamBuilder<Duration>(
              stream: _player.durationStream.map((duration) => duration ?? Duration.zero),
              builder: (context, snapshot) {
                final duration = snapshot.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: _player.positionStream.map((position) => position ?? Duration.zero),
                  builder: (context, snapshot) {
                    var position = snapshot.data ?? Duration.zero;
                    if (position > duration) {
                      position = duration;
                    }
                    return Slider(
                      value: position.inSeconds.toDouble(),
                      min: 0,
                      max: duration.inSeconds.toDouble(),
                      onChanged: (value) {
                        _player.seek(Duration(seconds: value.toInt()));
                      },
                    );
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
