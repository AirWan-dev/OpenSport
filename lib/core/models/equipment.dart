/// Matériel nécessaire à un exercice. Le nom de chaque valeur est stocké en
/// base et dans la bibliothèque fournie : ne pas renommer une valeur
/// existante sans migration.
enum Equipment {
  barbell('Barre'),
  ezBar('Barre EZ'),
  dumbbell('Haltères'),
  kettlebell('Kettlebell'),
  plate('Disque'),
  machine('Machine'),
  cable('Poulie'),
  band('Élastique'),
  bodyweight('Sans matériel'),
  other('Autre');

  const Equipment(this.label);

  final String label;
}
