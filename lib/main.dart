//ad mob logic with checking logic if it run on web
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize AdMob on mobile platforms
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      MobileAds.instance.initialize().then((initializationStatus) {
        initializationStatus.adapterStatuses.forEach((key, value) {
          debugPrint('Adapter status for $key: ${value.description}');
        });
        debugPrint('AdMob SDK initialized successfully');
      }).catchError((error) {
        debugPrint('AdMob initialization failed: $error');
      });
    } catch (e) {
      debugPrint('AdMob initialization error: $e');
    }
  } else {
    debugPrint('AdMob not supported on this platform (Web)');
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.light;
  late final AdManager _adManager;

  void toggleTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _adManager = AdManager();

    // Only load ads on supported platforms
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Add a small delay to ensure SDK is fully initialized
      Future.delayed(const Duration(seconds: 2), () {
        _adManager.loadInterstitialAd();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adManager.disposeAd();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed - checking ad status');
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        _adManager.loadInterstitialAd();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Instagram Reels',
      themeMode: _themeMode,
      theme: ThemeData(
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.black),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      darkTheme: ThemeData(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      debugShowCheckedModeBanner: false,
      home: ReelsScreen(
        toggleTheme: toggleTheme,
        currentThemeMode: _themeMode,
        adManager: _adManager,
      ),
    );
  }
}

class AdManager {
  InterstitialAd? _interstitialAd;
  int numMaxAdAttempts = 0;
  bool _isAdLoading = false;
  bool _isAdReady = false;
  bool _isSupported = false;

  final bool _debugMode = true;

  AdManager() {
    _isSupported = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    _logDebug('AdManager initialized. Platform supported: $_isSupported');
  }

  void loadInterstitialAd() {
    if (!_isSupported) {
      _logDebug('Ads not supported on this platform');
      return;
    }

    if (_isAdLoading) {
      _logDebug('Ad is already loading, skipping');
      return;
    }

    if (_isAdReady && _interstitialAd != null) {
      _logDebug('Ad is already loaded and ready');
      return;
    }

    _isAdLoading = true;
    _logDebug(
        'Starting to load interstitial ad (Attempt: ${numMaxAdAttempts + 1})');

    // Use test ad unit ID for testing, replace with your real ad unit ID for production
    String adUnitId;
    if (Platform.isAndroid) {
      // Test ad unit ID for Android interstitial
      adUnitId = 'ca-app-pub-1437018461695384/3749863070';
      // Your production ad unit ID (uncomment when ready for production)
      // adUnitId = 'ca-app-pub-1437018461695384/3749863070';
    } else if (Platform.isIOS) {
      // Test ad unit ID for iOS interstitial
      adUnitId = 'ca-app-pub-1437018461695384/3749863070';
      // Your production ad unit ID for iOS (replace with your actual iOS ad unit ID)
      // adUnitId = 'ca-app-pub-1437018461695384/YOUR_IOS_AD_UNIT_ID';
    } else {
      _logDebug('Unsupported platform for ads');
      _isAdLoading = false;
      return;
    }

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _logDebug('✅ Interstitial ad loaded successfully');
          _interstitialAd = ad;
          _isAdLoading = false;
          _isAdReady = true;
          numMaxAdAttempts = 0;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              _logDebug('Ad dismissed by user');
              _cleanupAndReload(ad);
            },
            onAdFailedToShowFullScreenContent:
                (InterstitialAd ad, AdError error) {
              _logDebug(
                  '❌ Ad failed to show: ${error.message} (Code: ${error.code})');
              _cleanupAndReload(ad);
            },
            onAdShowedFullScreenContent: (InterstitialAd ad) {
              _logDebug('✅ Ad displayed successfully');
            },
            onAdClicked: (InterstitialAd ad) {
              _logDebug('Ad clicked by user');
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _logDebug(
              '❌ Failed to load interstitial ad: ${error.message} (Code: ${error.code})');
          _isAdLoading = false;
          _isAdReady = false;
          _interstitialAd = null;

          numMaxAdAttempts += 1;
          if (numMaxAdAttempts <= 3) {
            int delaySeconds = numMaxAdAttempts * 3; // 3, 6, 9 seconds
            _logDebug(
                'Retrying ad load in $delaySeconds seconds (Attempt $numMaxAdAttempts/3)');
            Future.delayed(Duration(seconds: delaySeconds), () {
              if (mounted) {
                loadInterstitialAd();
              }
            });
          } else {
            _logDebug('Max retry attempts reached. Stopping ad load attempts.');
          }
        },
      ),
    );
  }

  void _cleanupAndReload(InterstitialAd ad) {
    _isAdReady = false;
    ad.dispose();
    // Preload next ad with a small delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        loadInterstitialAd();
      }
    });
  }

  bool get mounted => _isSupported; // Simple check for this example

  Future<bool> showAd() async {
    if (!_isSupported) {
      _logDebug('❌ Ads not supported on this platform');
      return false;
    }

    _logDebug(
        '🎯 Attempting to show ad. Ready: $_isAdReady, Loading: $_isAdLoading');

    if (_isAdReady && _interstitialAd != null) {
      try {
        await _interstitialAd!.show();
        _logDebug('✅ Ad show command executed successfully');
        return true;
      } catch (error) {
        _logDebug('❌ Error showing ad: $error');
        _isAdReady = false;
        _interstitialAd?.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        return false;
      }
    } else {
      _logDebug('⏳ Ad not ready. Loading: $_isAdLoading');
      if (!_isAdLoading) {
        _logDebug('🔄 Starting new ad load since none in progress');
        loadInterstitialAd();
      }
      return false;
    }
  }

  bool get isAdReady => _isAdReady && _interstitialAd != null;
  bool get isSupported => _isSupported;

  void disposeAd() {
    _logDebug('🗑️ Disposing ad manager');
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdReady = false;
    _isAdLoading = false;
  }

  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('🎬 AdManager: $message');
    }
  }
}

class ReelsScreen extends StatefulWidget {
  final Function(ThemeMode) toggleTheme;
  final ThemeMode currentThemeMode;
  final AdManager adManager;

  const ReelsScreen({
    Key? key,
    required this.toggleTheme,
    required this.currentThemeMode,
    required this.adManager,
  }) : super(key: key);

  @override
  _ReelsScreenState createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  final List<VideoPlayerController> _videoControllers = [];
  final List<ChewieController?> _chewieControllers = [];
  final List<bool> _videoInitialized = [];
  final List<bool> _videoLoading = [];
  int _currentPage = 0;
  bool _isMuted = false;
  Timer? _adTimer;

  final List<Post> posts = [
    Post(
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      username: 'salman__mughal7',
      caption: '❤️✌️ ... more',
      likes: '187',
      comments: '3,360',
      views: '63.5K',
      userAvatar: 'https://picsum.photos/150/150?random=1',
      isLiked: false,
      likedBy: 'rayyanfarukh6 and others',
    ),
    Post(
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      username: 'user2',
      caption: 'Check out this amazing content! #trending',
      likes: '89K',
      comments: '856',
      views: '120K',
      userAvatar: 'https://picsum.photos/150/150?random=2',
      isLiked: true,
      likedBy: 'friend1 and others',
    ),
    Post(
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
      username: 'user3',
      caption: 'Having fun today! 😊',
      likes: '45K',
      comments: '600',
      views: '78K',
      userAvatar: 'https://picsum.photos/150/150?random=3',
      isLiked: false,
      likedBy: 'friend2 and others',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: 0);

    // Initialize the lists with correct sizes
    for (int i = 0; i < posts.length; i++) {
      _videoInitialized.add(false);
      _videoLoading.add(true);
      _videoControllers.add(VideoPlayerController.network(posts[i].videoUrl));
      _chewieControllers.add(null);
    }

    _initializeVideos();
    _setupAdTimer();
  }

  void _setupAdTimer() {
    // Only set up timer for supported platforms
    if (widget.adManager.isSupported) {
      _adTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
        debugPrint('🕐 Periodic ad timer triggered');
        widget.adManager.loadInterstitialAd();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_videoControllers.isNotEmpty &&
          _currentPage < _videoControllers.length &&
          _videoInitialized[_currentPage] &&
          _videoControllers[_currentPage].value.isInitialized) {
        _videoControllers[_currentPage].play();
      }
      if (widget.adManager.isSupported) {
        widget.adManager.loadInterstitialAd();
      }
    } else if (state == AppLifecycleState.paused) {
      for (var controller in _videoControllers) {
        if (controller.value.isInitialized && controller.value.isPlaying) {
          controller.pause();
        }
      }
    }
  }

  Future<void> _initializeVideos() async {
    for (int i = 0; i < posts.length; i++) {
      final videoController = _videoControllers[i];
      try {
        await videoController.initialize().then((_) {
          if (!mounted) return;

          final chewieController = ChewieController(
            videoPlayerController: videoController,
            autoPlay: i == _currentPage,
            looping: true,
            allowPlaybackSpeedChanging: false,
            showControls: false,
            allowFullScreen: false,
          );

          setState(() {
            _chewieControllers[i] = chewieController;
            _videoInitialized[i] = true;
            _videoLoading[i] = false;
          });

          if (i == _currentPage) {
            videoController.play();
          }
        }).catchError((error) {
          debugPrint('Video initialization error for index $i: $error');
          if (mounted) {
            setState(() {
              _videoLoading[i] = false;
            });
          }
        });
      } catch (e) {
        debugPrint('Video setup error for index $i: $e');
        if (mounted) {
          setState(() {
            _videoLoading[i] = false;
          });
        }
      }
    }
    _applyMuteState();
  }

  void _applyMuteState() {
    for (var controller in _videoControllers) {
      if (controller.value.isInitialized) {
        controller.setVolume(_isMuted ? 0 : 1);
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _applyMuteState();
    });
  }

  void _showThemeOptions() {
    final isDarkMode = widget.currentThemeMode == ThemeMode.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.light_mode,
                    color: isDarkMode ? Colors.white : Colors.black),
                title: Text('Light Mode',
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black)),
                onTap: () {
                  widget.toggleTheme(ThemeMode.light);
                  Navigator.pop(context);
                },
                trailing: widget.currentThemeMode == ThemeMode.light
                    ? Icon(Icons.check,
                        color: isDarkMode ? Colors.white : Colors.black)
                    : null,
              ),
              ListTile(
                leading: Icon(Icons.dark_mode,
                    color: isDarkMode ? Colors.white : Colors.black),
                title: Text('Dark Mode',
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black)),
                onTap: () {
                  widget.toggleTheme(ThemeMode.dark);
                  Navigator.pop(context);
                },
                trailing: widget.currentThemeMode == ThemeMode.dark
                    ? Icon(Icons.check,
                        color: isDarkMode ? Colors.white : Colors.black)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adTimer?.cancel();
    _pageController.dispose();
    for (var controller in _videoControllers) {
      controller.dispose();
    }
    for (var controller in _chewieControllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int page) {
    for (int i = 0; i < _videoControllers.length; i++) {
      if (i == page) {
        if (_videoInitialized[i] && _videoControllers[i].value.isInitialized) {
          _videoControllers[i].play();
        }
      } else {
        if (_videoInitialized[i] && _videoControllers[i].value.isInitialized) {
          _videoControllers[i].pause();
        }
      }
    }

    if (mounted) {
      setState(() {
        _currentPage = page;
      });
    }

    // Show ad every 2 reels
    if (page > 0 && page % 2 == 0) {
      debugPrint('📱 Triggering ad after swiping to page $page');
      _showAdWithFeedback();
    }
  }

  Future<void> _showAdWithFeedback() async {
    if (!widget.adManager.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ads are not supported on this platform (Web)'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Loading advertisement...'),
        duration: Duration(seconds: 1),
      ),
    );

    bool adShown = await widget.adManager.showAd();

    if (!adShown) {
      // Show feedback if ad didn't show
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.adManager.isAdReady
                  ? 'Ad failed to display'
                  : 'Ad not ready yet, loading...'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: _onPageChanged,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return _buildPostItem(index);
          },
        ),
      ),
    );
  }

  Widget _buildPostItem(int index) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDarkMode ? Colors.black : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostHeader(posts[index]),
          Container(
            height: screenHeight * 0.55,
            width: double.infinity,
            color: Colors.black,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Center(child: _buildVideoWidget(index)),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildActionButtons(posts[index]),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0),
            child: Text(
              "Liked by ${posts[index].likedBy}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.0,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
                left: 16.0, top: 4.0, right: 16.0, bottom: 8.0),
            child: RichText(
              text: TextSpan(
                style:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                children: [
                  TextSpan(
                    text: "${posts[index].username} ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: posts[index].caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostHeader(Post post) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(post.userAvatar),
                backgroundColor: Colors.grey[300],
                onBackgroundImageError: (exception, stackTrace) {
                  debugPrint('Avatar load failed: $exception');
                },
                child: const Icon(Icons.person, size: 20, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.username,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const Text(
                    "Suggested for you",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Ad button with better visual feedback
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: widget.adManager.isSupported
                          ? (widget.adManager.isAdReady
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1))
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        widget.adManager.isSupported
                            ? Icons.ads_click
                            : Icons.web,
                        color: widget.adManager.isSupported
                            ? (widget.adManager.isAdReady
                                ? Colors.green
                                : Colors.orange)
                            : Colors.grey,
                      ),
                      onPressed: _showAdWithFeedback,
                      tooltip: widget.adManager.isSupported
                          ? (widget.adManager.isAdReady
                              ? 'Show Ad (Ready)'
                              : 'Show Ad (Loading)')
                          : 'Ads not supported on Web',
                    ),
                  ),
                  if (widget.adManager.isSupported)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: widget.adManager.isAdReady
                            ? Colors.green
                            : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        widget.adManager.isAdReady ? "✓" : "⏳",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  "Follow",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert,
                    color: isDarkMode ? Colors.white : Colors.black),
                onPressed: _showThemeOptions,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoWidget(int index) {
    if (_videoLoading[index]) {
      return const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
      );
    }

    if (!_videoInitialized[index] && !_videoLoading[index]) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            const Text("Video failed to load",
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              onPressed: () {
                setState(() {
                  _videoLoading[index] = true;
                });
                _initializeVideos();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        ),
      );
    }

    if (_chewieControllers[index] == null ||
        !_videoControllers[index].value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
      );
    }

    return AspectRatio(
      aspectRatio: _videoControllers[index].value.aspectRatio,
      child: GestureDetector(
        onTap: () {
          final controller = _videoControllers[index];
          setState(() {
            controller.value.isPlaying ? controller.pause() : controller.play();
          });
        },
        child: Chewie(controller: _chewieControllers[index]!),
      ),
    );
  }

  Widget _buildActionButtons(Post post) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: isDarkMode ? Colors.black : Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    post.isLiked = !post.isLiked;
                  });
                },
                child: Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 28,
                  color: post.isLiked
                      ? Colors.red
                      : (isDarkMode ? Colors.white : Colors.black),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.chat_bubble_outline,
                    size: 26, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              Icon(Icons.send,
                  size: 26, color: isDarkMode ? Colors.white : Colors.black),
            ],
          ),
          Icon(Icons.bookmark_border,
              size: 28, color: isDarkMode ? Colors.white : Colors.black),
        ],
      ),
    );
  }
}

class Post {
  final String videoUrl;
  final String username;
  final String caption;
  final String likes;
  final String comments;
  final String views;
  final String userAvatar;
  final String likedBy;
  bool isLiked;

  Post({
    required this.videoUrl,
    required this.username,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.views,
    required this.userAvatar,
    required this.likedBy,
    this.isLiked = false,
  });
}
// simple ad mob logic
// import 'package:flutter/material.dart';
// //import 'package:google_mobile_ads/google_mobile_ads.dart';
// import 'package:video_player/video_player.dart';
// import 'package:chewie/chewie.dart';
// import 'dart:io';
// import 'dart:async';
// import 'package:google_mobile_ads/google_mobile_ads.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // Initialize AdMob with logging enabled
//   MobileAds.instance.initialize().then((initializationStatus) {
//     // Log the initialization status for each adapter
//     initializationStatus.adapterStatuses.forEach((key, value) {
//       debugPrint('Adapter status for $key: ${value.description}');
//     });
//     debugPrint('AdMob SDK initialized');
//   });

//   runApp(MyApp());
// }

// class MyApp extends StatefulWidget {
//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
//   ThemeMode _themeMode = ThemeMode.light;
//   final AdManager _adManager = AdManager();

//   void toggleTheme(ThemeMode themeMode) {
//     setState(() {
//       _themeMode = themeMode;
//     });
//   }

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _adManager.loadInterstitialAd();
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _adManager.disposeAd();
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     // Reload ads when app comes back to foreground
//     if (state == AppLifecycleState.resumed) {
//       debugPrint('App resumed - checking ad status');
//       _adManager.loadInterstitialAd();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Instagram Reels',
//       themeMode: _themeMode,
//       theme: ThemeData(
//         primaryColor: Colors.white,
//         scaffoldBackgroundColor: Colors.white,
//         brightness: Brightness.light,
//         appBarTheme: const AppBarTheme(
//           backgroundColor: Colors.white,
//           iconTheme: IconThemeData(color: Colors.black),
//         ),
//         textTheme: const TextTheme(
//           bodyLarge: TextStyle(color: Colors.black),
//           bodyMedium: TextStyle(color: Colors.black),
//         ),
//         iconTheme: const IconThemeData(color: Colors.black),
//       ),
//       darkTheme: ThemeData(
//         primaryColor: Colors.black,
//         scaffoldBackgroundColor: Colors.black,
//         brightness: Brightness.dark,
//         appBarTheme: const AppBarTheme(
//           backgroundColor: Colors.black,
//           iconTheme: IconThemeData(color: Colors.white),
//         ),
//         textTheme: const TextTheme(
//           bodyLarge: TextStyle(color: Colors.white),
//           bodyMedium: TextStyle(color: Colors.white),
//         ),
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       debugShowCheckedModeBanner: false,
//       home: ReelsScreen(
//         toggleTheme: toggleTheme,
//         currentThemeMode: _themeMode,
//         adManager: _adManager,
//       ),
//     );
//   }
// }

// class AdManager {
//   InterstitialAd? _interstitialAd;
//   int numMaxAdAttempts = 0;
//   bool _isAdLoading = false;
//   bool _isAdReady = false;

//   // Debug flag for logging
//   final bool _debugMode = true;

//   void loadInterstitialAd() {
//     if (_isAdLoading) return;

//     _isAdLoading = true;
//     _logDebug('Starting to load interstitial ad');

//     InterstitialAd.load(
//       // Test ad unit ID for interstitial ads
//       adUnitId: 'ca-app-pub-1437018461695384/3749863070',
//       request: const AdRequest(),
//       adLoadCallback: InterstitialAdLoadCallback(
//         onAdLoaded: (InterstitialAd ad) {
//           _interstitialAd = ad;
//           _isAdLoading = false;
//           _isAdReady = true;
//           numMaxAdAttempts = 0;
//           _logDebug('Interstitial ad loaded successfully');

//           ad.fullScreenContentCallback = FullScreenContentCallback(
//             onAdDismissedFullScreenContent: (InterstitialAd ad) {
//               _logDebug('Ad dismissed');
//               _isAdReady = false;
//               ad.dispose();
//               loadInterstitialAd();
//             },
//             onAdFailedToShowFullScreenContent:
//                 (InterstitialAd ad, AdError error) {
//               _logDebug('Ad failed to show: ${error.message}');
//               _isAdReady = false;
//               ad.dispose();
//               loadInterstitialAd();
//             },
//             onAdShowedFullScreenContent: (InterstitialAd ad) {
//               _logDebug('Ad showed fullscreen content');
//             },
//           );
//         },
//         onAdFailedToLoad: (LoadAdError error) {
//           _logDebug('Failed to load interstitial ad: ${error.message}');
//           _isAdLoading = false;
//           _isAdReady = false;
//           _interstitialAd = null;

//           numMaxAdAttempts += 1;
//           if (numMaxAdAttempts <= 3) {
//             // Add exponential backoff for retries
//             Future.delayed(Duration(seconds: numMaxAdAttempts * 2), () {
//               loadInterstitialAd();
//             });
//           }
//         },
//       ),
//     );
//   }

//   void showAd() {
//     _logDebug('Attempting to show ad. Is ad ready? $_isAdReady');

//     if (_isAdReady && _interstitialAd != null) {
//       _interstitialAd!.show().catchError((error) {
//         _logDebug('Error showing ad: $error');
//         _isAdReady = false;
//         loadInterstitialAd();
//       });
//     } else if (!_isAdLoading) {
//       _logDebug('Ad not ready, attempting to load a new one');
//       loadInterstitialAd();
//     }
//   }

//   void disposeAd() {
//     _logDebug('Disposing ad');
//     _interstitialAd?.dispose();
//     _interstitialAd = null;
//     _isAdReady = false;
//   }

//   void _logDebug(String message) {
//     if (_debugMode) {
//       debugPrint('AdManager: $message');
//     }
//   }
// }

// class ReelsScreen extends StatefulWidget {
//   final Function(ThemeMode) toggleTheme;
//   final ThemeMode currentThemeMode;
//   final AdManager adManager;

//   const ReelsScreen({
//     Key? key,
//     required this.toggleTheme,
//     required this.currentThemeMode,
//     required this.adManager,
//   }) : super(key: key);

//   @override
//   _ReelsScreenState createState() => _ReelsScreenState();
// }

// class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
//   late PageController _pageController;
//   final List<VideoPlayerController> _videoControllers = [];
//   final List<ChewieController?> _chewieControllers = [];
//   final List<bool> _videoInitialized = [];
//   final List<bool> _videoLoading = [];
//   int _currentPage = 0;
//   bool _isMuted = false;
//   Timer? _adTimer;

//   final List<Post> posts = [
//     Post(
//       videoUrl:
//           'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
//       username: 'salman__mughal7',
//       caption: '❤️✌️ ... more',
//       likes: '187',
//       comments: '3,360',
//       views: '63.5K',
//       userAvatar: 'https://i.pravatar.cc/150?img=1',
//       isLiked: false,
//       likedBy: 'rayyanfarukh6 and others',
//     ),
//     Post(
//       videoUrl:
//           'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
//       username: 'user2',
//       caption: 'Check out this amazing content! #trending',
//       likes: '89K',
//       comments: '856',
//       views: '120K',
//       userAvatar: 'https://i.pravatar.cc/150?img=2',
//       isLiked: true,
//       likedBy: 'friend1 and others',
//     ),
//     Post(
//       videoUrl:
//           'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
//       username: 'user3',
//       caption: 'Having fun today! 😊',
//       likes: '45K',
//       comments: '600',
//       views: '78K',
//       userAvatar: 'https://i.pravatar.cc/150?img=3',
//       isLiked: false,
//       likedBy: 'friend2 and others',
//     ),
//   ];

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _pageController = PageController(initialPage: 0);

//     // Initialize the lists with correct sizes
//     for (int i = 0; i < posts.length; i++) {
//       _videoInitialized.add(false);
//       _videoLoading.add(true);
//       _videoControllers.add(VideoPlayerController.network(posts[i].videoUrl));
//       _chewieControllers.add(null);
//     }

//     // Initialize videos after the state is set up
//     _initializeVideos();

//     // Set up a timer to periodically try showing ads while user is watching
//     _setupAdTimer();
//   }

//   void _setupAdTimer() {
//     // Try showing an ad every 60 seconds while app is active
//     _adTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
//       debugPrint('Periodic ad timer triggered');
//       widget.adManager.loadInterstitialAd();
//     });
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       // Resume video playback and check ad status
//       if (_videoControllers.isNotEmpty &&
//           _currentPage < _videoControllers.length &&
//           _videoInitialized[_currentPage] &&
//           _videoControllers[_currentPage].value.isInitialized) {
//         _videoControllers[_currentPage].play();
//       }
//       widget.adManager.loadInterstitialAd();
//     } else if (state == AppLifecycleState.paused) {
//       // Pause videos when app goes to background
//       for (var controller in _videoControllers) {
//         if (controller.value.isInitialized && controller.value.isPlaying) {
//           controller.pause();
//         }
//       }
//     }
//   }

//   Future<void> _initializeVideos() async {
//     for (int i = 0; i < posts.length; i++) {
//       final videoController = _videoControllers[i];
//       try {
//         await videoController.initialize().then((_) {
//           if (!mounted) return;

//           final chewieController = ChewieController(
//             videoPlayerController: videoController,
//             autoPlay: i == _currentPage,
//             looping: true,
//             allowPlaybackSpeedChanging: false,
//             showControls: false,
//             allowFullScreen: false,
//           );

//           setState(() {
//             _chewieControllers[i] = chewieController;
//             _videoInitialized[i] = true;
//             _videoLoading[i] = false;
//           });

//           if (i == _currentPage) {
//             videoController.play();
//           }
//         }).catchError((error) {
//           if (mounted) {
//             setState(() {
//               _videoLoading[i] = false;
//             });
//           }
//         });
//       } catch (e) {
//         if (mounted) {
//           setState(() {
//             _videoLoading[i] = false;
//           });
//         }
//       }
//     }
//     _applyMuteState();
//   }

//   void _applyMuteState() {
//     for (var controller in _videoControllers) {
//       if (controller.value.isInitialized) {
//         controller.setVolume(_isMuted ? 0 : 1);
//       }
//     }
//   }

//   void _toggleMute() {
//     setState(() {
//       _isMuted = !_isMuted;
//       _applyMuteState();
//     });
//   }

//   void _showThemeOptions() {
//     final isDarkMode = widget.currentThemeMode == ThemeMode.dark;
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
//       builder: (context) {
//         return Container(
//           padding: const EdgeInsets.symmetric(vertical: 20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ListTile(
//                 leading: Icon(Icons.light_mode,
//                     color: isDarkMode ? Colors.white : Colors.black),
//                 title: Text('Light Mode',
//                     style: TextStyle(
//                         color: isDarkMode ? Colors.white : Colors.black)),
//                 onTap: () {
//                   widget.toggleTheme(ThemeMode.light);
//                   Navigator.pop(context);
//                 },
//                 trailing: widget.currentThemeMode == ThemeMode.light
//                     ? Icon(Icons.check,
//                         color: isDarkMode ? Colors.white : Colors.black)
//                     : null,
//               ),
//               ListTile(
//                 leading: Icon(Icons.dark_mode,
//                     color: isDarkMode ? Colors.white : Colors.black),
//                 title: Text('Dark Mode',
//                     style: TextStyle(
//                         color: isDarkMode ? Colors.white : Colors.black)),
//                 onTap: () {
//                   widget.toggleTheme(ThemeMode.dark);
//                   Navigator.pop(context);
//                 },
//                 trailing: widget.currentThemeMode == ThemeMode.dark
//                     ? Icon(Icons.check,
//                         color: isDarkMode ? Colors.white : Colors.black)
//                     : null,
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _adTimer?.cancel();
//     _pageController.dispose();
//     for (var controller in _videoControllers) {
//       controller.dispose();
//     }
//     for (var controller in _chewieControllers) {
//       controller?.dispose();
//     }
//     super.dispose();
//   }

//   void _onPageChanged(int page) {
//     for (int i = 0; i < _videoControllers.length; i++) {
//       if (i == page) {
//         if (_videoInitialized[i] && _videoControllers[i].value.isInitialized) {
//           _videoControllers[i].play();
//         }
//       } else {
//         if (_videoInitialized[i] && _videoControllers[i].value.isInitialized) {
//           _videoControllers[i].pause();
//         }
//       }
//     }

//     if (mounted) {
//       setState(() {
//         _currentPage = page;
//       });
//     }

//     // Show ad every 2 reels to increase ad display frequency
//     if (page > 0 && page % 2 == 0) {
//       debugPrint('Attempting to show ad after swiping to page $page');
//       widget.adManager.showAd();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isDarkMode = Theme.of(context).brightness == Brightness.dark;
//     return Scaffold(
//       backgroundColor: isDarkMode ? Colors.black : Colors.white,
//       body: SafeArea(
//         child: PageView.builder(
//           controller: _pageController,
//           scrollDirection: Axis.vertical,
//           onPageChanged: _onPageChanged,
//           itemCount: posts.length,
//           itemBuilder: (context, index) {
//             return _buildPostItem(index);
//           },
//         ),
//       ),
//     );
//   }

//   Widget _buildPostItem(int index) {
//     final screenHeight = MediaQuery.of(context).size.height;
//     final isDarkMode = Theme.of(context).brightness == Brightness.dark;

//     return Container(
//       color: isDarkMode ? Colors.black : Colors.white,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildPostHeader(posts[index]),
//           Container(
//             height: screenHeight * 0.55,
//             width: double.infinity,
//             color: Colors.black,
//             child: Stack(
//               alignment: Alignment.bottomRight,
//               children: [
//                 Center(child: _buildVideoWidget(index)),
//                 Positioned(
//                   bottom: 16,
//                   right: 16,
//                   child: GestureDetector(
//                     onTap: _toggleMute,
//                     child: Container(
//                       padding: const EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.5),
//                         shape: BoxShape.circle,
//                       ),
//                       child: Icon(
//                         _isMuted ? Icons.volume_off : Icons.volume_up,
//                         color: Colors.white,
//                         size: 20,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           _buildActionButtons(posts[index]),
//           Padding(
//             padding: const EdgeInsets.only(left: 16.0, right: 16.0),
//             child: Text(
//               "Liked by ${posts[index].likedBy}",
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 14.0,
//                 color: isDarkMode ? Colors.white : Colors.black,
//               ),
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.only(
//                 left: 16.0, top: 4.0, right: 16.0, bottom: 8.0),
//             child: RichText(
//               text: TextSpan(
//                 style:
//                     TextStyle(color: isDarkMode ? Colors.white : Colors.black),
//                 children: [
//                   TextSpan(
//                     text: "${posts[index].username} ",
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   TextSpan(text: posts[index].caption),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPostHeader(Post post) {
//     final isDarkMode = Theme.of(context).brightness == Brightness.dark;
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               CircleAvatar(
//                 radius: 16,
//                 backgroundImage: NetworkImage(post.userAvatar),
//                 // Add an error builder to handle image load failures
//                 onBackgroundImageError: (exception, stackTrace) {
//                   debugPrint('Failed to load avatar: $exception');
//                 },
//               ),
//               const SizedBox(width: 8),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     post.username,
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                       color: isDarkMode ? Colors.white : Colors.black,
//                     ),
//                   ),
//                   const Text(
//                     "Suggested for you",
//                     style: TextStyle(fontSize: 12, color: Colors.grey),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           Row(
//             children: [
//               // Ad button with visual indicator
//               Stack(
//                 alignment: Alignment.topRight,
//                 children: [
//                   IconButton(
//                     icon: Icon(Icons.ads_click),
//                     onPressed: () {
//                       // Show a loading indicator when ad button is pressed
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                           content: Text('Loading advertisement...'),
//                           duration: Duration(seconds: 1),
//                         ),
//                       );
//                       widget.adManager.showAd();
//                     },
//                     color: isDarkMode ? Colors.white : Colors.black,
//                   ),
//                   Container(
//                     padding: const EdgeInsets.all(4),
//                     decoration: const BoxDecoration(
//                       color: Colors.red,
//                       shape: BoxShape.circle,
//                     ),
//                     child: const Text(
//                       "!",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 10,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               TextButton(
//                 onPressed: () {},
//                 child: const Text(
//                   "Follow",
//                   style: TextStyle(
//                       fontWeight: FontWeight.bold, color: Colors.blue),
//                 ),
//               ),
//               IconButton(
//                 icon: Icon(Icons.more_vert,
//                     color: isDarkMode ? Colors.white : Colors.black),
//                 onPressed: _showThemeOptions,
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVideoWidget(int index) {
//     if (_videoLoading[index]) {
//       return const Center(
//         child: CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
//       );
//     }

//     if (!_videoInitialized[index] && !_videoLoading[index]) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.error_outline, color: Colors.red, size: 40),
//             const SizedBox(height: 12),
//             const Text("Video failed to load",
//                 style: TextStyle(color: Colors.white)),
//             const SizedBox(height: 16),
//             ElevatedButton.icon(
//               icon: const Icon(Icons.refresh),
//               label: const Text("Retry"),
//               onPressed: () {
//                 setState(() {
//                   _videoLoading[index] = true;
//                 });
//                 _initializeVideos();
//               },
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
//             ),
//           ],
//         ),
//       );
//     }

//     if (_chewieControllers[index] == null ||
//         !_videoControllers[index].value.isInitialized) {
//       return const Center(
//         child: CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
//       );
//     }

//     return AspectRatio(
//       aspectRatio: _videoControllers[index].value.aspectRatio,
//       child: GestureDetector(
//         onTap: () {
//           final controller = _videoControllers[index];
//           setState(() {
//             controller.value.isPlaying ? controller.pause() : controller.play();
//           });
//         },
//         child: Chewie(controller: _chewieControllers[index]!),
//       ),
//     );
//   }

//   Widget _buildActionButtons(Post post) {
//     final isDarkMode = Theme.of(context).brightness == Brightness.dark;
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//       color: isDarkMode ? Colors.black : Colors.white,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               GestureDetector(
//                 onTap: () {
//                   setState(() {
//                     post.isLiked = !post.isLiked;
//                   });
//                 },
//                 child: Icon(
//                   post.isLiked ? Icons.favorite : Icons.favorite_border,
//                   size: 28,
//                   color: post.isLiked
//                       ? Colors.red
//                       : (isDarkMode ? Colors.white : Colors.black),
//                 ),
//               ),
//               const SizedBox(width: 16),
//               IconButton(
//                 icon: Icon(Icons.chat_bubble_outline,
//                     size: 26, color: isDarkMode ? Colors.white : Colors.black),
//                 onPressed: () {},
//               ),
//               const SizedBox(width: 16),
//               Icon(Icons.send,
//                   size: 26, color: isDarkMode ? Colors.white : Colors.black),
//             ],
//           ),
//           Icon(Icons.bookmark_border,
//               size: 28, color: isDarkMode ? Colors.white : Colors.black),
//         ],
//       ),
//     );
//   }
// }

// class Post {
//   final String videoUrl;
//   final String username;
//   final String caption;
//   final String likes;
//   final String comments;
//   final String views;
//   final String userAvatar;
//   final String likedBy;
//   bool isLiked;

//   Post({
//     required this.videoUrl,
//     required this.username,
//     required this.caption,
//     required this.likes,
//     required this.comments,
//     required this.views,
//     required this.userAvatar,
//     required this.likedBy,
//     this.isLiked = false,
//   });
// }
// import 'package:flutter/material.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
// import 'package:video_player/video_player.dart';
// import 'package:chewie/chewie.dart';
// import 'interstitial_ad.dart';
// void main() async{
//   WidgetsFlutterBinding.ensureInitialized();
//    await MobileAds.instance.initialize();
//     // InterstitialAd.loadInterstitialAd(); // Pre-load the interstitial ad

//   runApp(MyApp());
// }

// class MyApp extends StatefulWidget {
//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   // Add theme mode state
//   ThemeMode _themeMode = ThemeMode.light;

//   // Method to toggle theme
//   void toggleTheme(ThemeMode themeMode) {
//     setState(() {
//       _themeMode = themeMode;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Instagram Reels',
//       themeMode: _themeMode,
//       theme: ThemeData(
//         primaryColor: Colors.white,
//         scaffoldBackgroundColor: Colors.white,
//         brightness: Brightness.light,
//         appBarTheme: AppBarTheme(
//           backgroundColor: Colors.white,
//           iconTheme: IconThemeData(color: Colors.black),
//         ),
//         textTheme: TextTheme(
//           bodyLarge: TextStyle(color: Colors.black),
//           bodyMedium: TextStyle(color: Colors.black),
//         ),
//         iconTheme: IconThemeData(color: Colors.black),
//       ),
//       darkTheme: ThemeData(
//         primaryColor: Colors.black,
//         scaffoldBackgroundColor: Colors.black,
//         brightness: Brightness.dark,
//         appBarTheme: AppBarTheme(
//           backgroundColor: Colors.black,
//           iconTheme: IconThemeData(color: Colors.white),
//         ),
//         textTheme: TextTheme(
//           bodyLarge: TextStyle(color: Colors.white),
//           bodyMedium: TextStyle(color: Colors.white),
//         ),
//         iconTheme: IconThemeData(color: Colors.white),
//       ),
//       debugShowCheckedModeBanner: false,
//       home: ReelsScreen(toggleTheme: toggleTheme, currentThemeMode: _themeMode),
//     );
//   }
// }

// class ReelsScreen extends StatefulWidget {
//   final Function(ThemeMode) toggleTheme;
//   final ThemeMode currentThemeMode;

//   ReelsScreen({required this.toggleTheme, required this.currentThemeMode});

//   @override
//   _ReelsScreenState createState() => _ReelsScreenState();
// }

// class _ReelsScreenState extends State<ReelsScreen> {
//   late PageController _pageController;
//   List<VideoPlayerController> _videoControllers = [];
//   List<ChewieController> _chewieControllers = [];
//   List<bool> _videoInitialized = [];
//   List<bool> _videoLoading = [];
//   int _currentPage = 0;
//   bool _isMuted = false;

//   final List<Post> posts = [
//     Post(
//       videoUrl:
//           'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
//       username: 'salman__mughal7',
//       caption: '❤️✌️ ... more',
//       likes: '187',
//       comments: '3,360',
//       views: '63.5K',
//       userAvatar: 'https://i.pravatar.cc/150?img=1',
//       isLiked: false,
//       likedBy: 'rayyanfarukh6 and others',
//     ),
//     Post(
//       videoUrl:
//           'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
//       username: 'user2',
//       caption: 'Check out this amazing content! #trending',
//       likes: '89K',
//       comments: '856',
//       views: '120K',
//       userAvatar: 'https://i.pravatar.cc/150?img=2',
//       isLiked: true,
//       likedBy: 'friend1 and others',
//     ),
//     Post(
//       videoUrl:
//           'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
//       username: 'user3',
//       caption: 'Having fun today! 😊',
//       likes: '45K',
//       comments: '600',
//       views: '78K',
//       userAvatar: 'https://i.pravatar.cc/150?img=3',
//       isLiked: false,
//       likedBy: 'friend2 and others',
//     ),
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _pageController = PageController(initialPage: 0);

//     // Initialize the tracking lists
//     for (int i = 0; i < posts.length; i++) {
//       _videoInitialized.add(false);
//       _videoLoading.add(true);
//     }

//     _initializeVideos();
//   }

//   void _initializeVideos() async {
//     // Pre-initialize the controllers
//     for (int i = 0; i < posts.length; i++) {
//       _videoControllers.add(VideoPlayerController.network(posts[i].videoUrl));
//     }

//     // Now initialize each video and set up listeners
//     for (int i = 0; i < posts.length; i++) {
//       final videoController = _videoControllers[i];

//       try {
//         // Start loading the video
//         await videoController.initialize().then((_) {
//           if (!mounted) return;

//           // Create chewie controller once video is initialized
//           final chewieController = ChewieController(
//             videoPlayerController: videoController,
//             autoPlay: i == _currentPage,
//             looping: true,
//             allowPlaybackSpeedChanging: false,
//             showControls: false,
//             allowFullScreen: false,
//           );

//           if (_chewieControllers.length <= i) {
//             _chewieControllers.add(chewieController);
//           } else {
//             _chewieControllers[i] = chewieController;
//           }

//           // Update state to show the video is now loaded
//           setState(() {
//             _videoInitialized[i] = true;
//             _videoLoading[i] = false;
//           });

//           // If this is the current page, play it
//           if (i == _currentPage) {
//             videoController.play();
//           }
//         }).catchError((error) {
//           debugPrint("Error initializing video $i: $error");
//           if (mounted) {
//             setState(() {
//               _videoLoading[i] = false;
//             });
//           }
//         });
//       } catch (e) {
//         debugPrint("Exception loading video $i: $e");
//         if (mounted) {
//           setState(() {
//             _videoLoading[i] = false;
//           });
//         }
//       }
//     }

//     _applyMuteState();
//   }

//   void _applyMuteState() {
//     for (var controller in _videoControllers) {
//       if (controller.value.isInitialized) {
//         controller.setVolume(_isMuted ? 0 : 1);
//       }
//     }
//   }

//   void _toggleMute() {
//     setState(() {
//       _isMuted = !_isMuted;
//       _applyMuteState();
//     });
//   }

//   void _showThemeOptions() {
//     final isDarkMode = widget.currentThemeMode == ThemeMode.dark;

//     showModalBottomSheet(
//       context: context,
//       backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.symmetric(vertical: 20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ListTile(
//                 leading: Icon(
//                   Icons.light_mode,
//                   color: isDarkMode ? Colors.white : Colors.black,
//                 ),
//                 title: Text(
//                   'Light Mode',
//                   style: TextStyle(
//                     color: isDarkMode ? Colors.white : Colors.black,
//                   ),
//                 ),
//                 onTap: () {
//                   widget.toggleTheme(ThemeMode.light);
//                   Navigator.pop(context);
//                 },
//                 trailing: widget.currentThemeMode == ThemeMode.light
//                     ? Icon(
//                         Icons.check,
//                         color: isDarkMode ? Colors.white : Colors.black,
//                       )
//                     : null,
//               ),
//               ListTile(
//                 leading: Icon(
//                   Icons.dark_mode,
//                   color: isDarkMode ? Colors.white : Colors.black,
//                 ),
//                 title: Text(
//                   'Dark Mode',
//                   style: TextStyle(
//                     color: isDarkMode ? Colors.white : Colors.black,
//                   ),
//                 ),
//                 onTap: () {
//                   widget.toggleTheme(ThemeMode.dark);
//                   Navigator.pop(context);
//                 },
//                 trailing: widget.currentThemeMode == ThemeMode.dark
//                     ? Icon(
//                         Icons.check,
//                         color: isDarkMode ? Colors.white : Colors.black,
//                       )
//                     : null,
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     for (var controller in _videoControllers) {
//       controller.dispose();
//     }
//     for (var controller in _chewieControllers) {
//       controller.dispose();
//     }
//     super.dispose();
//   }

//   void _onPageChanged(int page) {
//     // Pause all videos except the current one
//     for (int i = 0; i < _videoControllers.length; i++) {
//       if (i == page) {
//         if (_videoInitialized[i] && _videoControllers[i].value.isInitialized) {
//           _videoControllers[i].play();
//         }
//       } else {
//         if (_videoInitialized[i] && _videoControllers[i].value.isInitialized) {
//           _videoControllers[i].pause();
//         }
//       }
//     }

//     if (mounted) {
//       setState(() {
//         _currentPage = page;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Get theme mode
//     final isDarkMode = Theme.of(context).brightness == Brightness.dark;

//     return Scaffold(
//       backgroundColor: isDarkMode ? Colors.black : Colors.white,
//       body: SafeArea(
//         child: PageView.builder(
//           controller: _pageController,
//           scrollDirection: Axis.vertical,
//           onPageChanged: _onPageChanged,
//           itemCount: posts.length,
//           itemBuilder: (context, index) {
//             return _buildPostItem(index);
//           },
//         ),
//       ),
//     );
//   }

//   Widget _buildPostItem(int index) {
//     // Get screen height for better layout calculations
//     final screenHeight = MediaQuery.of(context).size.height;
//     final isDarkMode = Theme.of(context).brightness == Brightness.dark;

//     return Container(
//       color: isDarkMode ? Colors.black : Colors.white,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // User info header
//           _buildPostHeader(posts[index]),

//           // Post content (video)
//           Container(
//             height: screenHeight * 0.55, // Adjusted to prevent overflow
//             width: double.infinity,
//             color: Colors.black,
//             child: Stack(
//               alignment: Alignment.bottomRight,
//               children: [
//                 // Video content
//                 Center(
//                   child: _buildVideoWidget(index),
//                 ),

//                 // Sound toggle button
//                 Positioned(
//                   bottom: 16,
//                   right: 16,
//                   child: GestureDetector(
//                     onTap: _toggleMute,
//                     child: Container(
//                       padding: EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.5),
//                         shape: BoxShape.circle,
//                       ),
//                       child: Icon(
//                         _isMuted ? Icons.volume_off : Icons.volume_up,
//                         color: Colors.white,
//                         size: 20,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Action buttons
//           _buildActionButtons(posts[index]),

//           // Likes count
//           Padding(
//             padding: const EdgeInsets.only(left: 16.0, right: 16.0),
//             child: Text(
//               "Liked by ${posts[index].likedBy}",
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 14.0,
//                 color: isDarkMode ? Colors.white : Colors.black,
//               ),
//             ),
//           ),

//           // Caption
//           Padding(
//             padding: const EdgeInsets.only(
//                 left: 16.0, top: 4.0, right: 16.0, bottom: 8.0),
//             child: RichText(
//               text: TextSpan(
//                 style:
//                     TextStyle(color: isDarkMode ? Colors.white : Colors.black),
//                 children: [
//                   TextSpan(
//                     text: "${posts[index].username} ",
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   TextSpan(
//                     text: posts[index].caption,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPostHeader(Post post) {
//     final isDarkMode = Theme.of(context).brightness == Brightness.dark;

//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               CircleAvatar(
//                 radius: 16,
//                 backgroundImage: NetworkImage(post.userAvatar),
//               ),
//               SizedBox(width: 8),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     post.username,
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                       color: isDarkMode ? Colors.white : Colors.black,
//                     ),
//                   ),
//                   Text(
//                     "Suggested for you",
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.grey,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           Row(
//             children: [
//           ElevatedButton(
//             onPressed: () {
//               _loadAndShowInterstitialAd(); // Call ad display logic

//             },
//             child: const Text('Show Ad'),
//           ),
//               TextButton(
//                 onPressed: () {},
//                 child: Text(
//                   "Follow",
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     color: Colors.blue,
//                   ),
//                 ),
//               ),
//               IconButton(
//                 icon: Icon(
//                   Icons.more_vert,
//                   color: isDarkMode ? Colors.white : Colors.black,
//                 ),
//                 onPressed: _showThemeOptions,
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVideoWidget(int index) {
//     // Show loading spinner while video is initializing
//     if (_videoLoading[index]) {
//       return Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//         ),
//       );
//     }

//     // Show error state if initialization failed
//     if (!_videoInitialized[index] && !_videoLoading[index]) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.error_outline, color: Colors.red, size: 40),
//             SizedBox(height: 12),
//             Text("Video failed to load", style: TextStyle(color: Colors.white)),
//             SizedBox(height: 16),
//             ElevatedButton.icon(
//               icon: Icon(Icons.refresh),
//               label: Text("Retry"),
//               onPressed: () {
//                 setState(() {
//                   _videoLoading[index] = true;
//                 });
//                 _initializeVideos();
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//               ),
//             ),
//           ],
//         ),
//       );
//     }

//     // Video is initialized but controllers might not be ready yet
//     if (_chewieControllers.length <= index ||
//         !_videoControllers[index].value.isInitialized) {
//       return Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//         ),
//       );
//     }

//     // Video loaded successfully, show the video
//     return AspectRatio(
//       aspectRatio: _videoControllers[index].value.aspectRatio,
//       child: GestureDetector(
//         onTap: () {
//           final controller = _videoControllers[index];
//           setState(() {
//             controller.value.isPlaying ? controller.pause() : controller.play();
//           });
//         },
//         child: Chewie(controller: _chewieControllers[index]),
//       ),
//     );
//   }

//   Widget _buildActionButtons(Post post) {
//     final isDarkMode = Theme.of(context).brightness == Brightness.dark;

//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//       color: isDarkMode ? Colors.black : Colors.white,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               GestureDetector(
//                 onTap: () {
//                   setState(() {
//                     post.isLiked = !post.isLiked;
//                   });
//                 },
//                 child: Icon(
//                   post.isLiked ? Icons.favorite : Icons.favorite_border,
//                   size: 28,
//                   color: post.isLiked
//                       ? Colors.red
//                       : (isDarkMode ? Colors.white : Colors.black),
//                 ),
//               ),
//               SizedBox(width: 16),
//               IconButton(
//                   icon: Icon(
//                     Icons.chat_bubble_outline,
//                     size: 26,
//                     color: isDarkMode ? Colors.white : Colors.black,
//                   ),
//                   onPressed: () {}),
//               SizedBox(width: 16),
//               Icon(
//                 Icons.send,
//                 size: 26,
//                 color: isDarkMode ? Colors.white : Colors.black,
//               ),
//             ],
//           ),
//           Icon(
//             Icons.bookmark_border,
//             size: 28,
//             color: isDarkMode ? Colors.white : Colors.black,
//           ),
//         ],
//       ),
//     );
//   }
// }

// class Post {
//   final String videoUrl;
//   final String username;
//   final String caption;
//   final String likes;
//   final String comments;
//   final String views;
//   final String userAvatar;
//   final String likedBy;
//   bool isLiked;

//   Post({
//     required this.videoUrl,
//     required this.username,
//     required this.caption,
//     required this.likes,
//     required this.comments,
//     required this.views,
//     required this.userAvatar,
//     required this.likedBy,
//     this.isLiked = false,
//   });
// }
// import 'package:flutter/material.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
// import 'package:video_player/video_player.dart';
// import 'package:chewie/chewie.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   // await MobileAds.instance.initialize();
//   runApp(MyApp());
// }

// class MyApp extends StatefulWidget {
//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Instagram Reels',
//       theme: ThemeData(
//         primaryColor: Colors.white,
//         scaffoldBackgroundColor: Colors.white,
//       ),
//       debugShowCheckedModeBanner: false,
//       home: ReelsScreen(),
//     );
//   }
// }

// class ReelsScreen extends StatefulWidget {
//   @override
//   _ReelsScreenState createState() => _ReelsScreenState();
// }

// class _ReelsScreenState extends State<ReelsScreen> {
//   late PageController _pageController;
//   List<VideoPlayerController> _videoControllers = [];
//   List<ChewieController> _chewieControllers = [];
//   List<bool> _videoInitialized = [];
//   List<bool> _videoLoading = [];
//   int _currentPage = 0;
//   bool _isMuted = false;

//   final List<Post> posts = [
//     Post(
//       videoUrl:
//           'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
//       username: 'salman__mughal7',
//       caption: '❤️✌️ ... more',
//       likes: '187',
//       comments: '3,360',
//       views: '63.5K',
//       userAvatar: 'https://i.pravatar.cc/150?img=1',
//       isLiked: false,
//       likedBy: 'rayyanfarukh6 and others',
//     ),
//     Post(
//       videoUrl:
//           'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
//       username: 'user2',
//       caption: 'Check out this amazing content! #trending',
//       likes: '89K',
//       comments: '856',
//       views: '120K',
//       userAvatar: 'https://i.pravatar.cc/150?img=2',
//       isLiked: true,
//       likedBy: 'friend1 and others',
//     ),
//     Post(
//       videoUrl:
//           'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
//       username: 'user3',
//       caption: 'Having fun today! 😊',
//       likes: '45K',
//       comments: '600',
//       views: '78K',
//       userAvatar: 'https://i.pravatar.cc/150?img=3',
//       isLiked: false,
//       likedBy: 'friend2 and others',
//     ),
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _pageController = PageController(initialPage: 0);

//     // Initialize the tracking lists
//     for (int i = 0; i < posts.length; i++) {
//       _videoInitialized.add(false);
//       _videoLoading.add(true);
//     }

//     _initializeVideos();
//   }

//   void _initializeVideos() async {
//     // Pre-initialize the controllers
//     for (int i = 0; i < posts.length; i++) {
//       _videoControllers.add(VideoPlayerController.network(posts[i].videoUrl));
//     }

//     // Now initialize each video and set up listeners
//     for (int i = 0; i < posts.length; i++) {
//       final videoController = _videoControllers[i];

//       try {
//         // Start loading the video
//         await videoController.initialize().then((_) {
//           if (!mounted) return;

//           // Create chewie controller once video is initialized
//           final chewieController = ChewieController(
//             videoPlayerController: videoController,
//             autoPlay: i == _currentPage,
//             looping: true,
//             allowPlaybackSpeedChanging: false,
//             showControls: false,
//             allowFullScreen: false,
//           );

//           if (_chewieControllers.length <= i) {
//             _chewieControllers.add(chewieController);
//           } else {
//             _chewieControllers[i] = chewieController;
//           }

//           // Update state to show the video is now loaded
//           setState(() {
//             _videoInitialized[i] = true;
//             _videoLoading[i] = false;
//           });

//           // If this is the current page, play it
//           if (i == _currentPage) {
//             videoController.play();
//           }
//         }).catchError((error) {
//           debugPrint("Error initializing video $i: $error");
//           if (mounted) {
//             setState(() {
//               _videoLoading[i] = false;
//             });
//           }
//         });
//       } catch (e) {
//         debugPrint("Exception loading video $i: $e");
//         if (mounted) {
//           setState(() {
//             _videoLoading[i] = false;
//           });
//         }
//       }
//     }

//     _applyMuteState();
//   }

//   void _applyMuteState() {
//     for (var controller in _videoControllers) {
//       if (controller.value.isInitialized) {
//         controller.setVolume(_isMuted ? 0 : 1);
//       }
//     }
//   }

//   void _toggleMute() {
//     setState(() {
//       _isMuted = !_isMuted;
//       _applyMuteState();
//     });
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     for (var controller in _videoControllers) {
//       controller.dispose();
//     }
//     for (var controller in _chewieControllers) {
//       controller.dispose();
//     }
//     super.dispose();
//   }

//   void _onPageChanged(int page) {
//     // Pause all videos except the current one
//     for (int i = 0; i < _videoControllers.length; i++) {
//       if (i == page) {
//         if (_videoInitialized[i] && _videoControllers[i].value.isInitialized) {
//           _videoControllers[i].play();
//         }
//       } else {
//         if (_videoInitialized[i] && _videoControllers[i].value.isInitialized) {
//           _videoControllers[i].pause();
//         }
//       }
//     }

//     if (mounted) {
//       setState(() {
//         _currentPage = page;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: PageView.builder(
//           controller: _pageController,
//           scrollDirection: Axis.vertical,
//           onPageChanged: _onPageChanged,
//           itemCount: posts.length,
//           itemBuilder: (context, index) {
//             return _buildPostItem(index);
//           },
//         ),
//       ),
//     );
//   }

//   Widget _buildPostItem(int index) {
//     // Get screen height for better layout calculations
//     final screenHeight = MediaQuery.of(context).size.height;

//     return Container(
//       color: Colors.white,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // User info header
//           _buildPostHeader(posts[index]),

//           // Post content (video)
//           Container(
//             height: screenHeight * 0.55, // Adjusted to prevent overflow
//             width: double.infinity,
//             color: Colors.black,
//             child: Stack(
//               alignment: Alignment.bottomRight,
//               children: [
//                 // Video content
//                 Center(
//                   child: _buildVideoWidget(index),
//                 ),

//                 // Sound toggle button
//                 Positioned(
//                   bottom: 16,
//                   right: 16,
//                   child: GestureDetector(
//                     onTap: _toggleMute,
//                     child: Container(
//                       padding: EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.5),
//                         shape: BoxShape.circle,
//                       ),
//                       child: Icon(
//                         _isMuted ? Icons.volume_off : Icons.volume_up,
//                         color: Colors.white,
//                         size: 20,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Action buttons
//           _buildActionButtons(posts[index]),

//           // Likes count
//           Padding(
//             padding: const EdgeInsets.only(left: 16.0, right: 16.0),
//             child: Text(
//               "Liked by ${posts[index].likedBy}",
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 14.0,
//               ),
//             ),
//           ),

//           // Caption
//           Padding(
//             padding: const EdgeInsets.only(
//                 left: 16.0, top: 4.0, right: 16.0, bottom: 8.0),
//             child: RichText(
//               text: TextSpan(
//                 style: TextStyle(color: Colors.black),
//                 children: [
//                   TextSpan(
//                     text: "${posts[index].username} ",
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   TextSpan(
//                     text: posts[index].caption,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPostHeader(Post post) {
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               CircleAvatar(
//                 radius: 16,
//                 backgroundImage: NetworkImage(post.userAvatar),
//               ),
//               SizedBox(width: 8),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     post.username,
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                     ),
//                   ),
//                   Text(
//                     "Suggested for you",
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.grey,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           Row(
//             children: [
//               TextButton(
//                 onPressed: () {},
//                 child: Text(
//                   "Follow",
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     color: Colors.blue,
//                   ),
//                 ),
//               ),
//               IconButton(
//                 icon: Icon(Icons.more_vert),
//                 onPressed: () {},
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVideoWidget(int index) {
//     // Show loading spinner while video is initializing
//     if (_videoLoading[index]) {
//       return Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//         ),
//       );
//     }

//     // Show error state if initialization failed
//     if (!_videoInitialized[index] && !_videoLoading[index]) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.error_outline, color: Colors.red, size: 40),
//             SizedBox(height: 12),
//             Text("Video failed to load", style: TextStyle(color: Colors.white)),
//             SizedBox(height: 16),
//             ElevatedButton.icon(
//               icon: Icon(Icons.refresh),
//               label: Text("Retry"),
//               onPressed: () {
//                 setState(() {
//                   _videoLoading[index] = true;
//                 });
//                 _initializeVideos();
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//               ),
//             ),
//           ],
//         ),
//       );
//     }

//     // Video is initialized but controllers might not be ready yet
//     if (_chewieControllers.length <= index ||
//         !_videoControllers[index].value.isInitialized) {
//       return Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//         ),
//       );
//     }

//     // Video loaded successfully, show the video
//     return AspectRatio(
//       aspectRatio: _videoControllers[index].value.aspectRatio,
//       child: GestureDetector(
//         onTap: () {
//           final controller = _videoControllers[index];
//           setState(() {
//             controller.value.isPlaying ? controller.pause() : controller.play();
//           });
//         },
//         child: Chewie(controller: _chewieControllers[index]),
//       ),
//     );
//   }

//   Widget _buildActionButtons(Post post) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//       color: Colors.white,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               GestureDetector(
//                 onTap: () {
//                   setState(() {
//                     post.isLiked = !post.isLiked;
//                   });
//                 },
//                 child: Icon(
//                   post.isLiked ? Icons.favorite : Icons.favorite_border,
//                   size: 28,
//                   color: post.isLiked ? Colors.red : Colors.black,
//                 ),
//               ),
//               SizedBox(width: 16),
//               IconButton(
//                   icon: Image.asset(
//                     "assets/chat.png",
//                     height: 26,
//                     width: 26,
//                   ),
//                   onPressed: () {}),
//               SizedBox(width: 16),
//               Icon(Icons.send, size: 26),
//             ],
//           ),
//           Icon(Icons.bookmark_border, size: 28),
//         ],
//       ),
//     );
//   }
// }

// class Post {
//   final String videoUrl;
//   final String username;
//   final String caption;
//   final String likes;
//   final String comments;
//   final String views;
//   final String userAvatar;
//   final String likedBy;
//   bool isLiked;

//   Post({
//     required this.videoUrl,
//     required this.username,
//     required this.caption,
//     required this.likes,
//     required this.comments,
//     required this.views,
//     required this.userAvatar,
//     required this.likedBy,
//     this.isLiked = false,
//   });
// }

// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
// import 'package:chewie/chewie.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Instagram UI',
//       theme: ThemeData(
//         primaryColor: Colors.white,
//         scaffoldBackgroundColor: Colors.white,
//       ),
//       debugShowCheckedModeBanner: false,
//       home: InstagramScreen(),
//     );
//   }
// }

// class InstagramScreen extends StatefulWidget {
//   @override
//   _InstagramScreenState createState() => _InstagramScreenState();
// }

// class _InstagramScreenState extends State<InstagramScreen> {
//   late PageController _pageController;
//   List<VideoPlayerController> _videoControllers = [];
//   List<ChewieController> _chewieControllers = [];
//   List<bool> _videoInitialized = [];
//   List<bool> _videoLoading = [];
//   int _currentPage = 0;
//   bool _isMuted = false;
//   int _currentTabIndex = 0;

//   final List<Post> posts = [
//     Post(
//       videoUrl:
//           'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
//       username: 'salman__mughal7',
//       caption: '❤️✌️ ... more',
//       likes: '187',
//       comments: '3,360',
//       views: '63.5K',
//       userAvatar: 'https://i.pravatar.cc/150?img=1',
//       isLiked: false,
//       likedBy: 'rayyanfarukh6 and others',
//     ),
//     Post(
//       videoUrl:
//           'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
//       username: 'user2',
//       caption: 'Check out this amazing content! #trending',
//       likes: '89K',
//       comments: '856',
//       views: '120K',
//       userAvatar: 'https://i.pravatar.cc/150?img=2',
//       isLiked: true,
//       likedBy: 'friend1 and others',
//     ),
//     Post(
//       videoUrl:
//           'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
//       username: 'user3',
//       caption: 'Having fun today! 😊',
//       likes: '45K',
//       comments: '600',
//       views: '78K',
//       userAvatar: 'https://i.pravatar.cc/150?img=3',
//       isLiked: false,
//       likedBy: 'friend2 and others',
//     ),
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _pageController = PageController(initialPage: 0);

//     // Initialize the tracking lists
//     for (int i = 0; i < posts.length; i++) {
//       _videoInitialized.add(false);
//       _videoLoading.add(true);
//     }

//     _initializeVideos();
//   }

//   void _initializeVideos() async {
//     // Pre-initialize the controllers
//     for (int i = 0; i < posts.length; i++) {
//       _videoControllers.add(VideoPlayerController.network(posts[i].videoUrl));
//     }

//     // Now initialize each video and set up listeners
//     for (int i = 0; i < posts.length; i++) {
//       final videoController = _videoControllers[i];

//       try {
//         // Start loading the video
//         await videoController.initialize().then((_) {
//           if (!mounted) return;

//           // Create chewie controller once video is initialized
//           final chewieController = ChewieController(
//             videoPlayerController: videoController,
//             autoPlay: i == _currentPage,
//             looping: true,
//             allowPlaybackSpeedChanging: false,
//             showControls: false,
//             allowFullScreen: false,
//           );

//           if (_chewieControllers.length <= i) {
//             _chewieControllers.add(chewieController);
//           } else {
//             _chewieControllers[i] = chewieController;
//           }

//           // Update state to show the video is now loaded
//           setState(() {
//             _videoInitialized[i] = true;
//             _videoLoading[i] = false;
//           });

//           // If this is the current page, play it
//           if (i == _currentPage) {
//             videoController.play();
//           }
//         }).catchError((error) {
//           debugPrint("Error initializing video $i: $error");
//           if (mounted) {
//             setState(() {
//               _videoLoading[i] = false;
//             });
//           }
//         });
//       } catch (e) {
//         debugPrint("Exception loading video $i: $e");
//         if (mounted) {
//           setState(() {
//             _videoLoading[i] = false;
//           });
//         }
//       }
//     }

//     _applyMuteState();
//   }

//   void _applyMuteState() {
//     for (var controller in _videoControllers) {
//       if (controller.value.isInitialized) {
//         controller.setVolume(_isMuted ? 0 : 1);
//       }
//     }
//   }

//   void _toggleMute() {
//     setState(() {
//       _isMuted = !_isMuted;
//       _applyMuteState();
//     });
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     for (var controller in _videoControllers) {
//       controller.dispose();
//     }
//     for (var controller in _chewieControllers) {
//       controller.dispose();
//     }
//     super.dispose();
//   }

//   void _onPageChanged(int page) {
//     // Pause all videos except the current one
//     for (int i = 0; i < _videoControllers.length; i++) {
//       if (i == page) {
//         if (_videoInitialized[i] && _videoControllers[i].value.isInitialized) {
//           _videoControllers[i].play();
//         }
//       } else {
//         if (_videoInitialized[i] && _videoControllers[i].value.isInitialized) {
//           _videoControllers[i].pause();
//         }
//       }
//     }

//     if (mounted) {
//       setState(() {
//         _currentPage = page;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Column(
//         children: [
//           // Instagram App Bar
//           _buildInstagramAppBar(),

//           // Main Content
//           Expanded(
//             child: PageView.builder(
//               controller: _pageController,
//               scrollDirection: Axis.vertical,
//               onPageChanged: _onPageChanged,
//               itemCount: posts.length,
//               itemBuilder: (context, index) {
//                 return _buildPostItem(index);
//               },
//             ),
//           ),

//           // Bottom Navigation Bar
//           _buildBottomNavBar(),
//         ],
//       ),
//     );
//   }

//   Widget _buildInstagramAppBar() {
//     return Container(
//       color: Colors.white,
//       padding: EdgeInsets.only(top: 50.0, left: 16.0, right: 16.0, bottom: 8.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               Text(
//                 "Instagram",
//                 style: TextStyle(
//                   fontFamily: 'Billabong',
//                   fontSize: 32.0,
//                   color: Colors.black,
//                 ),
//               ),
//               Icon(Icons.keyboard_arrow_down),
//             ],
//           ),
//           Row(
//             children: [
//               Stack(
//                 children: [
//                   Icon(Icons.favorite_border, size: 28),
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       height: 10,
//                       width: 10,
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               SizedBox(width: 16),
//               Icon(Icons.messenger_outline, size: 28),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPostItem(int index) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // User info header
//         _buildPostHeader(posts[index]),

//         // Post content (video or image)
//         _buildPostContent(index),

//         // Action buttons
//         _buildActionButtons(posts[index]),

//         // Likes count
//         Padding(
//           padding: const EdgeInsets.only(left: 16.0, top: 8.0),
//           child: Text(
//             "Liked by ${posts[index].likedBy}",
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               fontSize: 14.0,
//             ),
//           ),
//         ),

//         // Caption
//         Padding(
//           padding: const EdgeInsets.only(left: 16.0, top: 4.0, right: 16.0),
//           child: RichText(
//             text: TextSpan(
//               style: TextStyle(color: Colors.black),
//               children: [
//                 TextSpan(
//                   text: "${posts[index].username} ",
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 TextSpan(
//                   text: posts[index].caption,
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildPostHeader(Post post) {
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               CircleAvatar(
//                 radius: 16,
//                 backgroundImage: NetworkImage(post.userAvatar),
//               ),
//               SizedBox(width: 8),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     post.username,
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                     ),
//                   ),
//                   Text(
//                     "Suggested for you",
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.grey,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           Row(
//             children: [
//               TextButton(
//                 onPressed: () {},
//                 child: Text(
//                   "Follow",
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     color: Colors.blue,
//                   ),
//                 ),
//               ),
//               Icon(Icons.more_horiz),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPostContent(int index) {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.6,
//       width: double.infinity,
//       color: Colors.black,
//       child: Stack(
//         alignment: Alignment.bottomRight,
//         children: [
//           // Video content
//           Center(
//             child: _buildVideoWidget(index),
//           ),

//           // Sound toggle button
//           Positioned(
//             bottom: 16,
//             right: 16,
//             child: GestureDetector(
//               onTap: _toggleMute,
//               child: Container(
//                 padding: EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(0.5),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(
//                   _isMuted ? Icons.volume_off : Icons.volume_up,
//                   color: Colors.white,
//                   size: 20,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVideoWidget(int index) {
//     // Show loading spinner while video is initializing
//     if (_videoLoading[index]) {
//       return Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//         ),
//       );
//     }

//     // Show error state if initialization failed
//     if (!_videoInitialized[index] && !_videoLoading[index]) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.error_outline, color: Colors.red, size: 40),
//             SizedBox(height: 12),
//             Text("Video failed to load", style: TextStyle(color: Colors.white)),
//             SizedBox(height: 16),
//             ElevatedButton.icon(
//               icon: Icon(Icons.refresh),
//               label: Text("Retry"),
//               onPressed: () {
//                 setState(() {
//                   _videoLoading[index] = true;
//                 });
//                 _initializeVideos();
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//               ),
//             ),
//           ],
//         ),
//       );
//     }

//     // Video is initialized but controllers might not be ready yet
//     if (_chewieControllers.length <= index ||
//         !_videoControllers[index].value.isInitialized) {
//       return Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//         ),
//       );
//     }

//     // Video loaded successfully, show the video
//     return AspectRatio(
//       aspectRatio: _videoControllers[index].value.aspectRatio,
//       child: GestureDetector(
//         onTap: () {
//           final controller = _videoControllers[index];
//           setState(() {
//             controller.value.isPlaying ? controller.pause() : controller.play();
//           });
//         },
//         child: Chewie(controller: _chewieControllers[index]),
//       ),
//     );
//   }

//   Widget _buildActionButtons(Post post) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//       color: Colors.white,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               GestureDetector(
//                 onTap: () {
//                   setState(() {
//                     post.isLiked = !post.isLiked;
//                   });
//                 },
//                 child: Icon(
//                   post.isLiked ? Icons.favorite : Icons.favorite_border,
//                   size: 28,
//                   color: post.isLiked ? Colors.red : Colors.black,
//                 ),
//               ),
//               SizedBox(width: 16),
//               Icon(Icons.chat_bubble_outline, size: 26),
//               SizedBox(width: 16),
//               Icon(Icons.send, size: 26),
//             ],
//           ),
//           Icon(Icons.bookmark_border, size: 28),
//         ],
//       ),
//     );
//   }

//   Widget _buildBottomNavBar() {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         border: Border(
//           top: BorderSide(color: Colors.grey.shade300, width: 0.5),
//         ),
//       ),
//       padding: EdgeInsets.symmetric(vertical: 12.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//         children: [
//           _buildNavItem(Icons.home, 0),
//           _buildNavItem(Icons.search, 1),
//           _buildNavItem(Icons.add_box_outlined, 2),
//           _buildNavItem(Icons.ondemand_video, 3),
//           CircleAvatar(
//             radius: 14,
//             backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=1'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildNavItem(IconData icon, int index) {
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           _currentTabIndex = index;
//         });
//       },
//       child: Icon(
//         icon,
//         size: 28,
//         color: _currentTabIndex == index ? Colors.black : Colors.black54,
//       ),
//     );
//   }
// }

// class Post {
//   final String videoUrl;
//   final String username;
//   final String caption;
//   final String likes;
//   final String comments;
//   final String views;
//   final String userAvatar;
//   final String likedBy;
//   bool isLiked;

//   Post({
//     required this.videoUrl,
//     required this.username,
//     required this.caption,
//     required this.likes,
//     required this.comments,
//     required this.views,
//     required this.userAvatar,
//     required this.likedBy,
//     this.isLiked = false,
//   });
// }
