import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'القرآن الكريم والأشعار',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        fontFamily: 'Roboto',
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// نماذج البيانات
class Reciter {
  final String id;
  final String name;
  final String serverUrl;

  Reciter({required this.id, required this.name, required this.serverUrl});
}

class PoemItem {
  final String id;
  final String title;
  final String poetName;
  final String audioUrl;

  PoemItem({
    required this.id,
    required this.title,
    required this.poetName,
    required this.audioUrl,
  });
}

// الشاشة الرئيسية مع شريط التنقل السفلي
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const QuranScreen(),
    const PoetryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'القرآن الكريم',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'الأشعار والقصائد',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. قسم القرآن الكريم
// ==========================================
class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Dio _dio = Dio();

  final List<Reciter> _reciters = [
    Reciter(
      id: '1',
      name: 'عبدالرحمن مسعد',
      serverUrl: 'https://server11.mp3quran.net/mussad/',
    ),
    Reciter(
      id: '2',
      name: 'محمد صديق المنشاوي',
      serverUrl: 'https://server10.mp3quran.net/minsh/',
    ),
    Reciter(
      id: '3',
      name: 'مشاري العفاسي',
      serverUrl: 'https://server8.mp3quran.net/afs/',
    ),
    Reciter(
      id: '4',
      name: 'عبدالباسط عبدالصمد',
      serverUrl: 'https://server7.mp3quran.net/basit/',
    ),
  ];

  int _selectedReciterIndex = 0;
  String? _currentlyPlayingSurah;
  bool _isPlaying = false;

  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _downloadedSurahs = {};

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _checkDownloadedFiles();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdLoaded = true),
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    );
    _bannerAd?.load();
  }

  Future<void> _checkDownloadedFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    for (int i = 1; i <= 114; i++) {
      String surahNum = i.toString().padLeft(3, '0');
      Reciter currentReciter = _reciters[_selectedReciterIndex];
      String filePath = '${dir.path}/quran_${currentReciter.id}_$surahNum.mp3';
      if (File(filePath).existsSync()) {
        setState(() {
          _downloadedSurahs['${currentReciter.id}_$surahNum'] = true;
        });
      }
    }
  }

  Future<void> _playAudio(String surahNum) async {
    Reciter currentReciter = _reciters[_selectedReciterIndex];
    String key = '${currentReciter.id}_$surahNum';
    final dir = await getApplicationDocumentsDirectory();
    String localPath = '${dir.path}/quran_$key.mp3';

    try {
      if (File(localPath).existsSync()) {
        await _audioPlayer.setFilePath(localPath);
      } else {
        String audioUrl = '${currentReciter.serverUrl}$surahNum.mp3';
        await _audioPlayer.setUrl(audioUrl);
      }

      _audioPlayer.play();
      setState(() {
        _currentlyPlayingSurah = surahNum;
        _isPlaying = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تشغيل السورة: $e')),
      );
    }
  }

  Future<void> _downloadSurah(String surahNum) async {
    Reciter currentReciter = _reciters[_selectedReciterIndex];
    String key = '${currentReciter.id}_$surahNum';
    String audioUrl = '${currentReciter.serverUrl}$surahNum.mp3';

    final dir = await getApplicationDocumentsDirectory();
    String savePath = '${dir.path}/quran_$key.mp3';

    try {
      await _dio.download(
        audioUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress[key] = received / total;
            });
          }
        },
      );

      setState(() {
        _downloadedSurahs[key] = true;
        _downloadProgress.remove(key);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تنزيل السورة بنجاح للاستماع أوفلاين!')),
      );
    } catch (e) {
      setState(() => _downloadProgress.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التنزيل: $e')),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Reciter activeReciter = _reciters[_selectedReciterIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('مكتبة القرآن الكريم'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // شريط القراء العلوي
          Container(
            height: 65,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.teal.shade50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _reciters.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedReciterIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedReciterIndex = index);
                    _checkDownloadedFiles();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.teal : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        _reciters[index].name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black80,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // قائمة السور
          Expanded(
            child: ListView.builder(
              itemCount: 114,
              itemBuilder: (context, index) {
                int surahIndex = index + 1;
                String surahNum = surahIndex.toString().padLeft(3, '0');
                String key = '${activeReciter.id}_$surahNum';

                bool isDownloaded = _downloadedSurahs[key] ?? false;
                double? progress = _downloadProgress[key];
                bool isCurrentPlaying = _currentlyPlayingSurah == surahNum && _isPlaying;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrentPlaying ? Colors.amber : Colors.teal.shade100,
                      child: Text('$surahIndex'),
                    ),
                    title: Text('سورة رقم $surahIndex', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      isDownloaded ? 'متوفرة بدون إنترنت' : 'تشغيل عبر الإنترنت',
                      style: TextStyle(color: isDownloaded ? Colors.green : Colors.grey, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isCurrentPlaying ? Icons.pause_circle : Icons.play_circle_fill,
                            color: Colors.teal,
                            size: 30,
                          ),
                          onPressed: () {
                            if (isCurrentPlaying) {
                              _audioPlayer.pause();
                              setState(() => _isPlaying = false);
                            } else {
                              _playAudio(surahNum);
                            }
                          },
                        ),
                        if (progress != null)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(value: progress, strokeWidth: 2),
                          )
                        else if (!isDownloaded)
                          IconButton(
                            icon: const Icon(Icons.download, color: Colors.blueGrey),
                            onPressed: () => _downloadSurah(surahNum),
                          )
                        else
                          const Icon(Icons.check_circle, color: Colors.green),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // الإعلان
          if (_isBannerAdLoaded && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. قسم الأشعار والقصائد
// ==========================================
class PoetryScreen extends StatefulWidget {
  const PoetryScreen({super.key});

  @override
  State<PoetryScreen> createState() => _PoetryScreenState();
}

class _PoetryScreenState extends State<PoetryScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Dio _dio = Dio();

  // قائمة الأشعار والقصائد داخل الكود (يمكنك تعديل الروابط والعناوين حسب رغبتك)
  final List<PoemItem> _poems = [
    PoemItem(
      id: 'p1',
      title: 'قصيدة ليس الغريب',
      poetName: 'زين العابدين علي بن الحسين',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', // رابط صوتي تجريبي
    ),
    PoemItem(
      id: 'p2',
      title: 'إلهي لستُ للفردوس أهلاً',
      poetName: 'أبو نواس',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    ),
    PoemItem(
      id: 'p3',
      title: 'قصيدة ولد الهدى فالكائنات ضياء',
      poetName: 'أحمد شوقي',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    ),
  ];

  String? _currentlyPlayingPoemId;
  bool _isPlaying = false;

  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _downloadedPoems = {};

  @override
  void initState() {
    super.initState();
    _checkDownloadedPoems();
  }

  Future<void> _checkDownloadedPoems() async {
    final dir = await getApplicationDocumentsDirectory();
    for (var poem in _poems) {
      String filePath = '${dir.path}/poem_${poem.id}.mp3';
      if (File(filePath).existsSync()) {
        setState(() {
          _downloadedPoems[poem.id] = true;
        });
      }
    }
  }

  Future<void> _playPoem(PoemItem poem) async {
    final dir = await getApplicationDocumentsDirectory();
    String localPath = '${dir.path}/poem_${poem.id}.mp3';

    try {
      if (File(localPath).existsSync()) {
        await _audioPlayer.setFilePath(localPath);
      } else {
        await _audioPlayer.setUrl(poem.audioUrl);
      }

      _audioPlayer.play();
      setState(() {
        _currentlyPlayingPoemId = poem.id;
        _isPlaying = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تشغيل القصيدة: $e')),
      );
    }
  }

  Future<void> _downloadPoem(PoemItem poem) async {
    final dir = await getApplicationDocumentsDirectory();
    String savePath = '${dir.path}/poem_${poem.id}.mp3';

    try {
      await _dio.download(
        poem.audioUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress[poem.id] = received / total;
            });
          }
        },
      );

      setState(() {
        _downloadedPoems[poem.id] = true;
        _downloadProgress.remove(poem.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تنزيل القصيدة بنجاح للاستماع أوفلاين!')),
      );
    } catch (e) {
      setState(() => _downloadProgress.remove(poem.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التنزيل: $e')),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مكتبة الأشعار والقصائد'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
      ),
      body: ListView.builder(
        itemCount: _poems.length,
        itemBuilder: (context, index) {
          PoemItem poem = _poems[index];
          bool isDownloaded = _downloadedPoems[poem.id] ?? false;
          double? progress = _downloadProgress[poem.id];
          bool isCurrentPlaying = _currentlyPlayingPoemId == poem.id && _isPlaying;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isCurrentPlaying ? Colors.amber : Colors.teal.shade200,
                child: const Icon(Icons.music_note, color: Colors.teal),
              ),
              title: Text(poem.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'الشاعر: ${poem.poetName} • ${isDownloaded ? "أوفلاين" : "أونلاين"}',
                style: TextStyle(color: isDownloaded ? Colors.green : Colors.grey.shade700, fontSize: 13),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isCurrentPlaying ? Icons.pause_circle : Icons.play_circle_fill,
                      color: Colors.teal,
                      size: 32,
                    ),
                    onPressed: () {
                      if (isCurrentPlaying) {
                        _audioPlayer.pause();
                        setState(() => _isPlaying = false);
                      } else {
                        _playPoem(poem);
                      }
                    },
                  ),
                  if (progress != null)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(value: progress, strokeWidth: 2),
                    )
                  else if (!isDownloaded)
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.blueGrey),
                      onPressed: () => _downloadPoem(poem),
                    )
                  else
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
