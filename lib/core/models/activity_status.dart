/// État d'une activité GPS. Le nom de chaque valeur est stocké en base.
enum ActivityStatus {
  /// Enregistrement en cours (ou interrompu par un arrêt brutal de l'app).
  recording,

  /// Terminée et enregistrée.
  finished,
}
