/// Search-only names received from the bundled, imported or external catalog.
List<String> parseCatalogAliases(Object? value) {
  if (value is! List) return const [];
  return List.unmodifiable({
    for (final item in value.whereType<String>())
      if (item.trim().isNotEmpty) item.trim(),
  });
}

bool catalogAliasesEqual(List<String> left, List<String> right) =>
    identical(left, right) ||
    (left.length == right.length &&
        left.indexed.every((pair) => pair.$2 == right[pair.$1]));
