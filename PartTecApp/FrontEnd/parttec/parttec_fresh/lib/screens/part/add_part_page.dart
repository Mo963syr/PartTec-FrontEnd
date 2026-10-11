import 'package:flutter/material.dart';
// Import the recommendation request page from the recommendation module
import '../recommendation/request_recommendation_page.dart';

class AddPartPage extends StatelessWidget {
  const AddPartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("طلب قطعة"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'ابحث عن اسم القطعة',
                prefixIcon: Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.confirmation_number),
              label: Text("بحث بالرقم التسلسلي"),
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.camera_alt),
              label: Text(
                "رفع صورة لتحليل القطعة",
                style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0)),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  minimumSize: Size(double.infinity, 50)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RequestRecommendationPage()),
                );
              },
              icon: Icon(Icons.assignment),
              label: Text("طلب قطعة توصية"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
