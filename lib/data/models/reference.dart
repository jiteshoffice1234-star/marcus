/// A single reference entry (rule, formula, ratio, standard summary...).
class ReferenceItem {
  const ReferenceItem({
    required this.title,
    required this.body,
    this.formula,
    this.category,
  });

  final String title;
  final String body;
  final String? formula;
  final String? category;

  factory ReferenceItem.fromJson(Map<String, dynamic> json) => ReferenceItem(
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        formula: json['formula'] as String?,
        category: json['category'] as String?,
      );
}

class ReferenceSection {
  const ReferenceSection({
    required this.id,
    required this.title,
    required this.description,
    this.items = const [],
  });

  final String id;
  final String title;
  final String description;
  final List<ReferenceItem> items;

  factory ReferenceSection.fromJson(Map<String, dynamic> json) =>
      ReferenceSection(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => ReferenceItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
