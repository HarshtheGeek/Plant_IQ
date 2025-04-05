import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:plant_iq/pages/chat_bot.dart';
import 'package:plant_iq/utils/gemini_api.dart';

class ImageChat extends StatefulWidget {
  const ImageChat({super.key});

  @override
  State<ImageChat> createState() => _ImageChatState();
}

class _ImageChatState extends State<ImageChat> {
  XFile? pickedImage;
  String mainResponse = '';
  List<String> followUpQuestions = [];
  Map<String, String> questionAnswers = {};
  bool scanning = false;
  bool generatingQuestion = false;
  late GoogleMapController _mapController;
  Position? _currentPosition;

  TextEditingController prompt = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final apiUrl ='https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_API';
  final systemPrompt ='''Your name is FarmGPT, and your role is to assist with everything related to farming. Respond in the language in which the user asks the question.
You will only address farming-related queries. Analyze farming images for the following purposes:
Identifying plant diseases and recommending remedies.
Analyzing soil types and recommending suitable crops.
Assessing plant health.
Identifying crop growth stages.
Identifying pests and suggesting control measures.
Do not respond to queries unrelated to agriculture and farming. If the provided image is not relevant to the context, ask the user to provide a suitable one for analysis.''';
  final header = {
    'Content-Type': 'application/json',
  };
  getImage(ImageSource ourSource) async {
    XFile? result = await _imagePicker.pickImage(source: ourSource);
    if (result != null) {
      setState(() {
        pickedImage = result;
        mainResponse = '';
        followUpQuestions = [];
        questionAnswers = {};
      });
    }
  }
  Future<void> generateFollowUpQuestions() async {
    setState(() {
      generatingQuestion = true;
    });

    try {
      const promptForQuestions =
          '''Based on the image analysis, generate 3 specific follow-up questions about:
    - Soil conditions and crop suitability
    - Plant health and disease management
    - Agricultural practices and improvements, if there is no valid response related to farming, tell the user to upload a valid image''';

      List<int> imageBytes = File(pickedImage!.path).readAsBytesSync();
      String base64File = base64.encode(imageBytes);

      final data = {
        "contents": [
          {
            "parts": [
              {"text": "$systemPrompt\n\n$mainResponse\n\n$promptForQuestions"},
              {
                "inlineData": {
                  "mimeType": "image/jpeg",
                  "data": base64File,
                }
              }
            ]
          }
        ],
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: header,
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        String questionsText =
            result['candidates'][0]['content']['parts'][0]['text'];
        followUpQuestions = questionsText
            .split('\n')
            .where((q) => q.trim().isNotEmpty)
            .map((q) => q.replaceAll(RegExp(r'^\d+\.\s*'), ''))
            .toList();
      }
    } catch (e) {
      print('Error generating questions: $e');
    }

    setState(() {
      generatingQuestion = false;
    });
  }
  Future<void> getAnswerForQuestion(String question) async {
    setState(() {
      scanning = true;
    });

    try {
      List<int> imageBytes = File(pickedImage!.path).readAsBytesSync();
      String base64File = base64.encode(imageBytes);

      final data = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    "$systemPrompt\n\n$mainResponse\n\n Based on this agricultural context and the image, provide a detailed farming-focused answer to: $question"
              },
              {
                "inlineData": {
                  "mimeType": "image/jpeg",
                  "data": base64File,
                }
              }
            ]
          }
        ],
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: header,
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        String answer = result['candidates'][0]['content']['parts'][0]['text'];
        setState(() {
          questionAnswers[question] = answer;
        });
      }
    } catch (e) {
      print('Error getting answer: $e');
    }

    setState(() {
      scanning = false;
    });
  }
  getdata(image, promptValue) async {
    setState(() {
      scanning = true;
      mainResponse = '';
      followUpQuestions = [];
      questionAnswers = {};
    });

    try {
      List<int> imageBytes = File(image.path).readAsBytesSync();
      String base64File = base64.encode(imageBytes);

      final data = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    "$systemPrompt\n\nAnalyze this agricultural image and provide insights about:\n1. Plant/crop health status\n2. Any visible diseases or pest damage\n3. Soil condition assessment if visible\n4. Recommended actions or treatments\n\nUser query: $promptValue"
              },
              {
                "inlineData": {
                  "mimeType": "image/jpeg",
                  "data": base64File,
                }
              }
            ]
          }
        ],
      };

      await http
          .post(Uri.parse(apiUrl), headers: header, body: jsonEncode(data))
          .then((response) async {
        if (response.statusCode == 200) {
          var result = jsonDecode(response.body);
          mainResponse = result['candidates'][0]['content']['parts'][0]['text'];
          await generateFollowUpQuestions();
        } else {
          mainResponse = 'Response status : ${response.statusCode}';
        }
      }).catchError((error) {
        print('Error occurred $error');
      });
    } catch (e) {
      print('Error occurred $e');
    }

    setState(() {
      scanning = false;
    });
  }
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'FarmGPT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Color(0xFF2E7D32),
        actions: [
          IconButton(
            onPressed: () => getImage(ImageSource.gallery),
            icon: const Icon(
              Icons.insert_photo_rounded,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: () => getImage(ImageSource.camera),
            icon: const Icon(
              Icons.camera_enhance,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF2E7D32),
                      width: 1,
                    ),
                  ),
                  child: pickedImage == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.agriculture_rounded,
                              size: 50,
                              color: Color(0xFF2E7D32),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Upload farm or crop image',
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(
                            File(pickedImage!.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: prompt,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(color: Color(0xFF2E7D32)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(color: Color(0xFF2E7D32)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide:
                        const BorderSide(color: Color(0xFF2E7D32), width: 2),
                  ),
                  prefixIcon: const Icon(
                    Icons.agriculture_rounded,
                    color: Color(0xFF2E7D32),
                  ),
                  hintText: 'Ask about crop health, diseases, or soil',
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: pickedImage == null
                    ? null
                    : () => getdata(pickedImage, prompt.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Analyze Image',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (scanning || generatingQuestion)
                const Center(
                  child: SpinKitFadingCircle(
                    color: Color(0xFF2E7D32),
                    size: 20,
                  )
                ),
              if (mainResponse.isNotEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Farm Analysis:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Markdown(
                          data: mainResponse,
                          shrinkWrap: true,
                          physics: const PageScrollPhysics(),
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(fontSize: 16, color: Colors.black87),
                            h1: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                            ),
                            h2: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4CAF50)
                            ),
                            h3: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF81C784)
                            ),
                            strong: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32)
                            ),
                            em: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF4CAF50)
                            ),
                            listBullet: const TextStyle(color: Color(0xFF2E7D32)),
                            blockquote: const TextStyle(
                                color: Colors.black54,
                                fontStyle: FontStyle.italic,
                                fontSize: 16
                            ),
                            code: const TextStyle(
                                backgroundColor: Color(0xFFF0F0F0),
                                color: Colors.black87,
                                fontFamily: 'monospace',
                                fontSize: 14
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (followUpQuestions.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Agricultural Insights:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 10),
                ...followUpQuestions.map((question) => Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    title: Text(
                      question,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    children: [
                      if (!questionAnswers.containsKey(question) &&
                          !scanning)
                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: ElevatedButton(
                            onPressed: () => getAnswerForQuestion(question),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              iconColor: Colors.white,
                            ),
                            child: const Text(
                              'Get Farming Advice',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      if (questionAnswers.containsKey(question))
                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Markdown(
                            data: questionAnswers[question]!,
                            shrinkWrap: true,
                            physics: const PageScrollPhysics(),
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(fontSize: 16, color: Colors.black87),
                              h1: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32)
                              ),
                              h2: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50)
                              ),
                              h3: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF81C784)
                              ),
                              strong: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32)
                              ),
                              em: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF4CAF50)
                              ),
                              listBullet: const TextStyle(color: Color(0xFF2E7D32)),
                              blockquote: const TextStyle(
                                  color: Colors.black54,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 16
                              ),
                              code: const TextStyle(
                                  backgroundColor: Color(0xFFF0F0F0),
                                  color: Colors.black87,
                                  fontFamily: 'monospace',
                                  fontSize: 14
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatBot()));
        },
        backgroundColor: Colors.green,
        child: Icon(Icons.chat_bubble,color: Colors.white,),
      ),

    );
  }
}
