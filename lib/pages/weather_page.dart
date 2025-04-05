import 'package:flutter/material.dart';
import 'package:plant_iq/utils/consts.dart';
import 'package:weather/weather.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final WeatherFactory _weatherFactory = WeatherFactory(API_KEY);
  Weather? _weather;
  @override
  void initState() {
    super.initState();
    _weatherFactory.currentWeatherByCityName('Kolkata').then((w) {
      setState(() {
        _weather = w;
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Application'),
      ),
      body: _BuildUI(),
    );
  }
  Widget _BuildUI() {
    if (_weather == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Center();
  }
}
