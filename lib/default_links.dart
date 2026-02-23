class LinkItem {
  final String title;
  final String url;

  LinkItem({required this.title, required this.url});

  Map<String, String> toJson() {
    return {
      'title': title,
      'url': url,
    };
  }

  factory LinkItem.fromJson(Map<String, dynamic> json) {
    return LinkItem(
      title: json['title'] as String,
      url: json['url'] as String,
    );
  }
}

// Default links that will be loaded on first launch
final List<LinkItem> defaultLinks = [
  LinkItem(
    title: 'test ',
    url: 'https://cyprus-league.tziapouras.online/live-update',
  ),

];
