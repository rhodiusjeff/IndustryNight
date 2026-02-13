/// Specialty categories
enum SpecialtyCategory {
  beauty('Beauty'),
  photoVideo('Photo & Video'),
  production('Production'),
  talent('Talent'),
  musicAudio('Music & Audio'),
  design('Design'),
  other('Other');

  const SpecialtyCategory(this.displayName);
  final String displayName;
}

/// Industry specialties for user profiles
/// IDs match the database specialties table
class Specialty {
  final String id;
  final String name;
  final SpecialtyCategory category;

  const Specialty({
    required this.id,
    required this.name,
    required this.category,
  });

  // Beauty
  static const hairStylist = Specialty(id: 'hair_stylist', name: 'Hair Stylist', category: SpecialtyCategory.beauty);
  static const makeupArtist = Specialty(id: 'makeup_artist', name: 'Makeup Artist', category: SpecialtyCategory.beauty);
  static const nailTech = Specialty(id: 'nail_tech', name: 'Nail Technician', category: SpecialtyCategory.beauty);
  static const esthetician = Specialty(id: 'esthetician', name: 'Esthetician', category: SpecialtyCategory.beauty);
  static const barber = Specialty(id: 'barber', name: 'Barber', category: SpecialtyCategory.beauty);

  // Photo & Video
  static const photographer = Specialty(id: 'photographer', name: 'Photographer', category: SpecialtyCategory.photoVideo);
  static const videographer = Specialty(id: 'videographer', name: 'Videographer', category: SpecialtyCategory.photoVideo);
  static const editor = Specialty(id: 'editor', name: 'Photo/Video Editor', category: SpecialtyCategory.photoVideo);
  static const colorist = Specialty(id: 'colorist', name: 'Colorist', category: SpecialtyCategory.photoVideo);

  // Production
  static const producer = Specialty(id: 'producer', name: 'Producer', category: SpecialtyCategory.production);
  static const director = Specialty(id: 'director', name: 'Director', category: SpecialtyCategory.production);
  static const creativeDirector = Specialty(id: 'creative_director', name: 'Creative Director', category: SpecialtyCategory.production);
  static const artDirector = Specialty(id: 'art_director', name: 'Art Director', category: SpecialtyCategory.production);
  static const productionAssistant = Specialty(id: 'production_assistant', name: 'Production Assistant', category: SpecialtyCategory.production);

  // Talent
  static const model = Specialty(id: 'model', name: 'Model', category: SpecialtyCategory.talent);
  static const actor = Specialty(id: 'actor', name: 'Actor', category: SpecialtyCategory.talent);
  static const dancer = Specialty(id: 'dancer', name: 'Dancer', category: SpecialtyCategory.talent);
  static const influencer = Specialty(id: 'influencer', name: 'Influencer/Content Creator', category: SpecialtyCategory.talent);

  // Music & Audio
  static const dj = Specialty(id: 'dj', name: 'DJ', category: SpecialtyCategory.musicAudio);
  static const musicProducer = Specialty(id: 'music_producer', name: 'Music Producer', category: SpecialtyCategory.musicAudio);
  static const soundEngineer = Specialty(id: 'sound_engineer', name: 'Sound Engineer', category: SpecialtyCategory.musicAudio);
  static const musician = Specialty(id: 'musician', name: 'Musician', category: SpecialtyCategory.musicAudio);

  // Design
  static const fashionDesigner = Specialty(id: 'fashion_designer', name: 'Fashion Designer', category: SpecialtyCategory.design);
  static const graphicDesigner = Specialty(id: 'graphic_designer', name: 'Graphic Designer', category: SpecialtyCategory.design);
  static const stylist = Specialty(id: 'stylist', name: 'Wardrobe Stylist', category: SpecialtyCategory.design);
  static const setDesigner = Specialty(id: 'set_designer', name: 'Set Designer', category: SpecialtyCategory.design);

  // Other
  static const writer = Specialty(id: 'writer', name: 'Writer/Copywriter', category: SpecialtyCategory.other);
  static const artist = Specialty(id: 'artist', name: 'Visual Artist', category: SpecialtyCategory.other);
  static const animator = Specialty(id: 'animator', name: 'Animator', category: SpecialtyCategory.other);
  static const other = Specialty(id: 'other', name: 'Other', category: SpecialtyCategory.other);

  /// All available specialties
  static const List<Specialty> all = [
    // Beauty
    hairStylist, makeupArtist, nailTech, esthetician, barber,
    // Photo & Video
    photographer, videographer, editor, colorist,
    // Production
    producer, director, creativeDirector, artDirector, productionAssistant,
    // Talent
    model, actor, dancer, influencer,
    // Music & Audio
    dj, musicProducer, soundEngineer, musician,
    // Design
    fashionDesigner, graphicDesigner, stylist, setDesigner,
    // Other
    writer, artist, animator, other,
  ];

  /// Find specialty by ID
  static Specialty? fromId(String id) {
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get specialties by category
  static List<Specialty> byCategory(SpecialtyCategory category) {
    return all.where((s) => s.category == category).toList();
  }

  /// Get specialties grouped by category
  static Map<SpecialtyCategory, List<Specialty>> get grouped {
    final map = <SpecialtyCategory, List<Specialty>>{};
    for (final category in SpecialtyCategory.values) {
      map[category] = byCategory(category);
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Specialty && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Specialty($id)';
}
