import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: MainNavigation(),
));

class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  // We'll pass "AAPL" as a default for the demo
  final List<Widget> _pages = [HomeFeed(), SearchScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Feed"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
        ],
      ),
    );
  }
}

// --- SCREEN 1: HOME FEED ---
class HomeFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Market Pulse")),
      body: Center(child: Text("Live Cards Coming in Part 3")),
    );
  }
}

// --- SCREEN 2: SEARCH ---
class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Find Company")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: "Enter Ticker (TSLA, AAPL)", border: OutlineInputBorder()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => CompanyDetail(ticker: _controller.text.toUpperCase())
                ));
              }, 
              child: Text("Analyze")
            )
          ],
        ),
      ),
    );
  }
}

// --- SCREEN 3: COMPANY DETAIL (The Meat of the App) ---
class CompanyDetail extends StatefulWidget {
  final String ticker;
  CompanyDetail({required this.ticker});
  @override
  _CompanyDetailState createState() => _CompanyDetailState();
}

class _CompanyDetailState extends State<CompanyDetail> {
  Map? data;
  bool isLoading = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  // Inside _CompanyDetailState

fetchData() async {
  try {
    final res = await http.get(Uri.parse('http://127.0.0.1:8000/pulse/${widget.ticker}'));
    final decodedData = json.decode(res.body);
    
    setState(() {
      data = decodedData;
      isLoading = false;
    });
    
    // Debug print to your console so you can see the raw data
    print("Received Price: ${data?['current_price']}");
    print("Chart Points Count: ${data?['chart_points']?.length}");
  } catch (e) {
    setState(() {
      errorMessage = "Error: $e";
      isLoading = false;
    });
  }
}
  @override
  Widget build(BuildContext context) {
    if (isLoading) return Scaffold(body: Center(child: CircularProgressIndicator()));
    
    if (errorMessage.isNotEmpty) return Scaffold(body: Center(child: Text(errorMessage)));

    // Safely extract lists with fallback to empty lists to prevent the "Null" error
    List chartPoints = data?['chart_points'] ?? [];
    List events = data?['events'] ?? [];

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      appBar: AppBar(title: Text("${widget.ticker} Analysis")),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Header Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("\$${data?['current_price'] ?? '0.00'}", 
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              Text("LIVE PULSE", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 20),
          
          // CHART SECTION - Only shows if we have points
          if (chartPoints.isNotEmpty)
            Container(
              height: 200,
              child: LineChart(LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: chartPoints.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                    isCurved: true,
                    color: Colors.blueAccent,
                    dotData: FlDotData(show: false),
                  )
                ],
                titlesData: FlTitlesData(show: false),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
              )),
            )
          else
            Center(child: Text("No chart data available")),

          SizedBox(height: 20),
          Text("AI Detected Events", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          
          // EVENT CARDS
          ...events.map((e) => Card(
            margin: EdgeInsets.symmetric(vertical: 8),
            color: _getEventColor(e['event_type'] ?? 'neutral').withOpacity(0.2),
            child: ListTile(
              title: Text(e['title'] ?? "No Title", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(e['event_type']?.toString().toUpperCase() ?? "GENERAL"),
              trailing: Text("${((e['confidence'] ?? 0) * 100).toStringAsFixed(0)}%"),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Color _getEventColor(String type) {
    if (type.contains('layoff')) return Colors.redAccent;
    if (type.contains('merger') || type.contains('acquisition')) return Colors.greenAccent;
    if (type.contains('split')) return Colors.orangeAccent;
    return Colors.grey;
  }
}