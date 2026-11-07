import '../models/sport_event.dart';

const currentDemoUser = EventDemoUser(
  id: 'demo-user-001',
  name: 'Sami Ben Amor',
  city: 'Tunis',
  latitude: 36.8065,
  longitude: 10.1815,
  isCoach: true,
  activityLevel: 'Intermédiaire',
  goals: ['Endurance', 'Rester actif'],
  interests: [EventCategory.running, EventCategory.sport, EventCategory.health],
);

const demoParticipantNames = {
  'demo-maya': 'Maya Trabelsi',
  'demo-youssef': 'Youssef Khaldi',
  'demo-ines': 'Ines Jaziri',
};

const demoCityCoordinates = <String, (double, double)>{
  'Tunis': (36.8065, 10.1815),
  'Sousse': (35.8256, 10.63699),
  'Ariana': (36.8665, 10.1945),
};

List<SportEvent> createDemoEvents() {
  final now = DateTime.now();
  return [
    SportEvent(
      id: 'demo-running',
      title: 'Run du lac : allure progressive',
      description: 'Une sortie running accessible avec échauffement, conseils d’allure et retour au calme.',
      category: EventCategory.running,
      dateTime: now.add(const Duration(days: 2, hours: 2)),
      mode: EventMode.inPerson,
      city: 'Tunis',
      location: 'Berges du lac',
      price: 0,
      capacity: 12,
      coachId: currentDemoUser.id,
      coachName: currentDemoUser.name,
      latitude: 36.8320,
      longitude: 10.2350,
      attendeeIds: ['demo-maya', 'demo-youssef', 'demo-ines'],
    ),
    SportEvent(
      id: 'demo-nutrition',
      title: 'Atelier nutrition et énergie',
      description: 'Comprendre les repas autour de l’entraînement et repartir avec des idées simples.',
      category: EventCategory.nutrition,
      dateTime: now.add(const Duration(days: 4, hours: 4)),
      mode: EventMode.hybrid,
      city: 'Tunis',
      location: 'Centre-ville / lien envoyé après inscription',
      price: 25,
      capacity: 2,
      coachId: 'coach-leila',
      coachName: 'Leila Mansour',
      latitude: 36.8008,
      longitude: 10.1800,
      attendeeIds: ['demo-maya', 'demo-youssef'],
      waitlistIds: ['demo-ines'],
    ),
    SportEvent(
      id: 'demo-mobility',
      title: 'Mobilité et récupération',
      description: 'Séance douce pour travailler la mobilité, la respiration et la récupération.',
      category: EventCategory.health,
      dateTime: now.add(const Duration(days: 8, hours: 3)),
      mode: EventMode.online,
      city: 'Sousse',
      location: 'Lien de visioconférence',
      price: 0,
      capacity: 20,
      coachId: 'coach-amir',
      coachName: 'Amir Gharbi',
      latitude: 35.8256,
      longitude: 10.63699,
    ),
    SportEvent(
      id: 'demo-strength',
      title: 'Renforcement fonctionnel débutant',
      description: 'Un entraînement en petit groupe avec variantes selon le niveau de chacun.',
      category: EventCategory.sport,
      dateTime: now.add(const Duration(days: 12, hours: 5)),
      mode: EventMode.inPerson,
      city: 'Ariana',
      location: 'Parc Ennahli',
      price: 15,
      capacity: 10,
      coachId: 'coach-salma',
      coachName: 'Salma Trabelsi',
      latitude: 36.8665,
      longitude: 10.1945,
      attendeeIds: ['demo-youssef'],
    ),
  ];
}