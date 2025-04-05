import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:plant_iq/pages/admin_page.dart';
import 'package:plant_iq/pages/chat_bot.dart';
import 'package:plant_iq/pages/description_generator.dart';
import 'package:plant_iq/pages/weather_page.dart';
import 'package:plant_iq/splash/splash_screen.dart';
import 'package:plant_iq/utils/Api_key.dart';

void main() async {
  Gemini.init(apiKey: GEMINI_API_KEY);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: AdminPanel(),
    );
  }
}
