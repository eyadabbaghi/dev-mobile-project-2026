import 'package:flutter/material.dart';
import '../../models/ai_recommendation.dart';
import '../../services/ai/ai_recommendation_service.dart';
import '../../services/auth_service.dart';

class AiRecommendationsScreen extends StatefulWidget {
  final AuthService authService;

  const AiRecommendationsScreen({super.key, required this.authService});

  @override
  State<AiRecommendationsScreen> createState() => _AiRecommendationsScreenState();
}

class _AiRecommendationsScreenState extends State<AiRecommendationsScreen> {
  final AiRecommendationService _service = AiRecommendationService();
  List<AiRecommendation> _recommendations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = widget.authService.currentUser;
    if (user != null) {
      final list = await _service.getRecommendations(user.id);
      if (mounted) {
        setState(() {
          _recommendations = list;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Recommandations AI')),
      body: _recommendations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('Aucune recommandation pour le moment.'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _recommendations.length,
                itemBuilder: (context, index) {
                  final rec = _recommendations[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.psychology, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(rec.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              if (!rec.isRead)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                                  child: Text('Nouveau', style: TextStyle(color: Theme.of(context).scaffoldBackgroundColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(rec.description, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
