import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MahSolver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  XFile? _image;
  String _responseBody = "";
  bool _isSending = false;
  String custPrompt = "";
  //TextEditingController _textController = TextEditingController();

  Future<void> _getImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      ImageCropper cropper = ImageCropper();
      final croppedImage = await cropper.cropImage(
        sourcePath: image.path,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio3x2,
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9
        ],
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Cropper',
              toolbarColor: Colors.deepOrange,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false),
          IOSUiSettings(
            title: 'Cropper',
          ),
          WebUiSettings(
            context: context,
          ),
        ],
      );
      setState(() {
        _image = croppedImage != null ? XFile(croppedImage.path) : null;
      });
    } else {
      setState(() {
        _isSending = true;
      });
    }
  }

  Future<void> sendImageToGemini(XFile? file) async {
    if (file != null) {
      String base64image = base64Encode(File(file.path).readAsBytesSync());
      String apiKey = 'AIzaSyAo03nkvD-8uvfbX4NjPnjNdPRffcmgSy4';
      String requestBody = json.encode(
        {
          "contents": [
            {
              "parts": [
                {"text": "input: "},
                {
                  "inlineData": {"mimeType": "image/jpeg", "data": base64image}
                },
                {
                  "text": custPrompt == ""
                      ? "solve the equation in the image step by step and explain each step"
                      : custPrompt
                },
                {"text": "output: "},
                {"text": "input: "},
                {"text": "output: "}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.4,
            "topK": 32,
            "topP": 1,
            "maxOutputTokens": 4096,
            "stopSequences": []
          },
          "safetySettings": [
            {
              "category": "HARM_CATEGORY_HARASSMENT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_HATE_SPEECH",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            }
          ]
        },
      );
      http.Response response = await http.post(
        Uri.parse(
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.0-pro-vision-latest:generateContent?key=$apiKey"),
        headers: {"Content-Type": "application/json"},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonBody = json.decode(response.body);
        setState(() {
          _responseBody =
              jsonBody["candidates"][0]["content"]["parts"][0]["text"];
          _isSending = false;
        });
        print("Image sent successfully");
        print(response.body);
      } else {
        print("request failed");
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  _openCamera() {
    if (_image != null) {
      _getImageFromCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MathSolver'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  _image == null
                      ? const Text("No image selected")
                      : Image.file(File(_image!.path)),
                  const SizedBox(
                    height: 10,
                  ),
                  /* TextField(
                    controller: _textController,
                    onChanged: (val) => custPrompt = val,
                  ), */
                  const SizedBox(
                    height: 20,
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _responseBody,
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                ],
              ),
            ),
            if (_isSending)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.deepPurpleAccent,
                ),
              )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _image == null ? _openCamera() : sendImageToGemini(_image);
        },
        tooltip: _image == null ? "Pick image" : "Send image",
        child: Icon(_image == null ? Icons.camera_alt : Icons.send),
      ),
    );
  }
}
