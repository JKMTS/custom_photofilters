import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as imageLib;
import 'package:path_provider/path_provider.dart';
import 'package:photofilters/photofilters.dart';
import 'package:path/path.dart';

class SelectedCroppedImages extends StatefulWidget {
  const SelectedCroppedImages(
      {Key? key, required this.croppedImages, required this.frame})
      : super(key: key);
  final List<File> croppedImages;
  final bool frame;

  @override
  State<SelectedCroppedImages> createState() => _SelectedCroppedImagesState();
}

class _SelectedCroppedImagesState extends State<SelectedCroppedImages> {
  final GlobalKey globalKey = GlobalKey();
  List<GlobalKey> globalKeys = [];
  List<imageLib.Image> originalImages = [];
  List<SelectedImageAndColor> images = [];
  String? fileName;
  List<Filter> selectedFilters = [];
  List<bool> isBasicEdit = [];
  List<File> originalFiles = [];
  bool isLoading = false;
  bool showEditAndResetButton = true;

  makeLoading() {
    setState(() {
      isLoading = true;
    });
  }

  makeNotLoading() {
    setState(() {
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800)).then((value) {
        init();
      });
    });
  }

  init() async {
    originalImages = [];
    selectedFilters = [];
    originalFiles = [];
    for (var element in widget.croppedImages) {
      var image = imageLib.decodeImage(await element.readAsBytes());
      originalImages.add(image!);
      selectedFilters.add(presetFiltersList[0]);
      isBasicEdit.add(false);
      originalFiles.add(element);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green,
          title: const Text("Images"),
          leading: IconButton(
            onPressed: () async {
              final directory =
                  Directory("data/user/0/com.example.example/cache");
              bool exist = await directory.exists();
              if (exist) {
                await directory.delete(recursive: true);
              }
              // Get.back();
            },
            icon: const Icon(Icons.arrow_back_ios),
          ),
          actions: [
            IconButton(
                onPressed: () {
                  if (!widget.frame || !showEditAndResetButton) {
                    // Get.back(result: widget.croppedImages);
                  } else {
                    // showBotToast("Add Frames");
                    setState(() {
                      showEditAndResetButton = false;
                    });
                  }
                },
                icon: Icon(Icons.check_circle_outline_outlined))
          ],
        ),
        body: PageView.builder(
          itemBuilder: (context, index) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 15,
                  ),
                  Text("${index + 1} /${widget.croppedImages.length}"),
                  SizedBox(
                    height: 20,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Stack(
                      alignment: Alignment.topLeft,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.file(
                            widget.croppedImages[index],
                            fit: BoxFit.fill,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              if (showEditAndResetButton)
                                GestureDetector(
                                  onTap: () async {
                                    makeLoading();
                                    fileName = basename(
                                        widget.croppedImages[index].path);
                                    var a = await widget.croppedImages[index]
                                        .readAsBytes();
                                    var image = imageLib.decodeImage(a);
                                    Map? imagefile = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PhotoFilterSelector(
                                          title: const Text("Choose Filter"),
                                          appBarColor: Colors.green,
                                          image: image!,
                                          filename: fileName!,
                                          loader: const Center(
                                              child:
                                                  CupertinoActivityIndicator()),
                                          fit: BoxFit.contain,
                                          filters: presetFiltersList,
                                          originalImage: isBasicEdit[index]
                                              ? image
                                              : originalImages[index],
                                          imageFilter: selectedFilters[index],
                                        ),
                                      ),
                                    );
                                    if (imagefile != null &&
                                        imagefile
                                            .containsKey("image_filtered")) {
                                      setState(() {
                                        widget.croppedImages[index] =
                                            imagefile["image_filtered"];
                                        selectedFilters[index] =
                                            imagefile["filter"];
                                        isBasicEdit[index] =
                                            imagefile["is_basic_edit"];
                                      });
                                    }
                                    makeNotLoading();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      padding: const EdgeInsets.all(8.0),
                                      decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white),
                                      child: isLoading
                                          ? CupertinoActivityIndicator()
                                          : const Icon(
                                              Icons.edit,
                                              color: Colors.black,
                                            ),
                                    ),
                                  ),
                                ),
                              if (showEditAndResetButton)
                                GestureDetector(
                                  onTap: () async {
                                    setState(() {
                                      isBasicEdit[index] = false;
                                      selectedFilters[index] =
                                          presetFiltersList[0];
                                      widget.croppedImages[index] =
                                          originalFiles[index];
                                    });
                                    var img = await widget.croppedImages[index]
                                        .readAsBytes();
                                    var image = imageLib.decodeImage(img);
                                    setState(() {
                                      if (image != null) {
                                        originalImages[index] = image;
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      padding: const EdgeInsets.all(8.0),
                                      decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white),
                                      child: const Icon(
                                        Icons.refresh_rounded,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          itemCount: widget.croppedImages.length,
        ));
  }
}

class SelectedImageAndColor {
  File image;
  Color color;

  SelectedImageAndColor({Key? key, required this.image, required this.color});
}
