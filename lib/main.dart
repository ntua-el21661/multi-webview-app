import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'default_links.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CL-SERVER',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  List<LinkItem> _savedLinks = [];
  int _currentLinkIndex = 0;
  WebViewController? _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedLinks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Reload the current website when app is reopened
      if (_webViewController != null && _savedLinks.isNotEmpty) {
        _webViewController!.reload();
      }
    }
  }

  Future<void> _loadSavedLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final linksJson = prefs.getStringList('saved_links');
    final currentIndex = prefs.getInt('current_link_index') ?? 0;
    
    if (linksJson != null && linksJson.isNotEmpty) {
      setState(() {
        _savedLinks = linksJson
            .map((json) => LinkItem.fromJson(jsonDecode(json)))
            .toList();
        _currentLinkIndex = currentIndex.clamp(0, _savedLinks.length - 1);
      });
      _initializeWebView(_savedLinks[_currentLinkIndex].url);
    } else {
      // Load default links on first launch
      await _loadDefaultLinks();
    }
  }

  Future<void> _loadDefaultLinks() async {
    _savedLinks = List.from(defaultLinks);
    await _saveLinksToPrefs();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_link_index', 0);
    
    if (_savedLinks.isNotEmpty) {
      setState(() {
        _currentLinkIndex = 0;
        _isLoading = true;
      });
      _initializeWebView(_savedLinks[0].url);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLinksToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final linksJson = _savedLinks
        .map((link) => jsonEncode(link.toJson()))
        .toList();
    await prefs.setStringList('saved_links', linksJson);
  }

  Future<void> _saveLink() async {
    String title = _titleController.text.trim();
    String url = _urlController.text.trim();
    
    if (url.isEmpty) {
      _showSnackBar('Please enter a URL');
      return;
    }

    if (title.isEmpty) {
      _showSnackBar('Please enter a title');
      return;
    }

    // Add https:// if no protocol is specified
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    // Check if URL already exists
    if (_savedLinks.any((link) => link.url == url)) {
      _showSnackBar('URL already exists');
      return;
    }

    _savedLinks.add(LinkItem(title: title, url: url));
    await _saveLinksToPrefs();
    
    // Set the new link as current
    _currentLinkIndex = _savedLinks.length - 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_link_index', _currentLinkIndex);

    setState(() {
      _isLoading = true;
    });

    _initializeWebView(url);
    _showSnackBar('Link added successfully (${_savedLinks.length} total)');
  }

  Future<void> _switchToLink(int index) async {
    if (_savedLinks.isEmpty || index < 0 || index >= _savedLinks.length) return;

    _currentLinkIndex = index;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_link_index', _currentLinkIndex);

    setState(() {
      _isLoading = true;
    });

    _initializeWebView(_savedLinks[_currentLinkIndex].url);
    _showSnackBar('Switched to: ${_savedLinks[_currentLinkIndex].title}');
  }

  void _showLinkSelectionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Select a Link',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _savedLinks.length,
                itemBuilder: (context, index) {
                  final link = _savedLinks[index];
                  final isCurrent = index == _currentLinkIndex;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrent 
                          ? Colors.deepPurple 
                          : Colors.grey.shade300,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      link.title,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      link.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _switchToLink(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _initializeWebView(String url) {
    _webViewController = WebViewController()
      ..enableZoom(false)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            // Disable zooming to feel more static
            _webViewController?.runJavaScript('''
              var meta = document.querySelector('meta[name="viewport"]');
              if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'viewport';
                document.head.appendChild(meta);
              }
              meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
              document.body.style.touchAction = 'pan-x pan-y';
            ''');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            _showSnackBar('Error loading page: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {});
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showUrlInput() {
    _urlController.clear();
    _titleController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'My Website',
                labelText: 'Title',
                icon: Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'https://example.com',
                labelText: 'URL',
                icon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveLink();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showManageUrls() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Links (${_savedLinks.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _savedLinks.length,
            itemBuilder: (context, index) {
              final link = _savedLinks[index];
              final isCurrent = index == _currentLinkIndex;
              return ListTile(
                leading: Icon(
                  isCurrent ? Icons.check_circle : Icons.link,
                  color: isCurrent ? Colors.green : Colors.grey,
                ),
                title: Text(
                  link.title,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  link.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await _deleteLink(index);
                    Navigator.pop(context);
                  },
                ),
                onTap: () async {
                  _currentLinkIndex = index;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('current_link_index', _currentLinkIndex);
                  setState(() {
                    _isLoading = true;
                  });
                  _initializeWebView(_savedLinks[_currentLinkIndex].url);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLink(int index) async {
    _savedLinks.removeAt(index);
    await _saveLinksToPrefs();

    if (_savedLinks.isEmpty) {
      _currentLinkIndex = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_link_index', 0);
      setState(() {
        _webViewController = null;
        _isLoading = false;
      });
    } else {
      if (_currentLinkIndex >= _savedLinks.length) {
        _currentLinkIndex = _savedLinks.length - 1;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_link_index', _currentLinkIndex);
      setState(() {
        _isLoading = true;
      });
      _initializeWebView(_savedLinks[_currentLinkIndex].url);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF001f3f),
        foregroundColor: Colors.white,
        title: Text(
          _savedLinks.isEmpty 
              ? 'CL-SERVER' 
              : _savedLinks[_currentLinkIndex].title,
        ),
        actions: [
          if (_savedLinks.length > 1)
            IconButton(
              icon: const Icon(Icons.apps),
              onPressed: _showLinkSelectionSheet,
              tooltip: 'Choose Link',
            ),
          if (_savedLinks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: _showManageUrls,
              tooltip: 'Manage Links',
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showUrlInput,
            tooltip: 'Add Link',
          ),
        ],
      ),
      body: _savedLinks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.language,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No links saved yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showUrlInput,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Link'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                if (_webViewController != null)
                  WebViewWidget(controller: _webViewController!),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),

    );
  }
}
