/// Type d'une série de musculation. Le nom de chaque valeur est stocké en base.
enum SetKind {
  normal('Normale'),

  /// Ne compte ni dans le volume ni dans les records.
  warmup('Échauffement');

  const SetKind(this.label);

  final String label;
}
