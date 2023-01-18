// ignore_for_file: sdk_version_ui_as_code

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:photofilters/photofilters.dart';
import 'package:image/image.dart' as imageLib;
import 'package:image_picker/image_picker.dart';

void main() => runApp(new MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String fileName;
  List<Filter> filters = presetFiltersList;
  final picker = ImagePicker();
  List<File> imageFiles = [];
  File imageFile;
  List<imageLib.Image> originalImages = [];
  List<Filter> selectedFilters = [];
  List<bool> isBasicEdit = [];

  Future getImage(context) async {
    final pickedFile = await picker.getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      imageFiles.add(File(pickedFile.path));
      imageFiles.forEach((element) async {
        var image = imageLib.decodeImage(await element.readAsBytes());
        originalImages.add(image);
        selectedFilters.add(presetFiltersList[0]);
        isBasicEdit.add(false);
      });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Photo Filter Example'),
      ),
      body: Center(
        child: new Container(
          child: imageFiles.isEmpty
              ? Center(
                  child: new Text('No image selected.'),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      ...List.generate(
                          imageFiles.length,
                          (index) => GestureDetector(
                              onTap: () async {
                                setState(() {
                                  imageFile = null;
                                });
                                imageFile = new File(imageFiles[index].path);
                                fileName = basename(imageFile.path);
                                var image = imageLib
                                    .decodeImage(await imageFile.readAsBytes());
                                Map imagefile = await Navigator.push(
                                  context,
                                  new MaterialPageRoute(
                                    builder: (context) =>
                                        new PhotoFilterSelector(
                                      title: Text("Photo Filter Example"),
                                      image: image,
                                      filters: presetFiltersList,
                                      filename: fileName,
                                      loader: Center(
                                          child: CircularProgressIndicator()),
                                      fit: BoxFit.contain,
                                      originalImage: isBasicEdit[index]
                                          ? image
                                          : originalImages[index],
                                      imageFilter: selectedFilters[index],
                                    ),
                                  ),
                                );
                                if (imagefile != null &&
                                    imagefile.containsKey('image_filtered')) {
                                  debugPrint("inside the condition");
                                  setState(() {
                                    imageFiles[index] =
                                        imagefile['image_filtered'];
                                    selectedFilters[index] =
                                        imagefile["filter"];
                                    isBasicEdit[index] =
                                        imagefile["is_basic_edit"];
                                  });
                                  print(imageFile.path);
                                }
                              },
                              child: Image.file(File(imageFiles[index].path))))
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () => getImage(context),
        tooltip: 'Pick Image',
        child: new Icon(Icons.add_a_photo),
      ),
    );
  }
}
