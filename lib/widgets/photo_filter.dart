import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:colorfilter_generator/addons.dart';
import 'package:colorfilter_generator/colorfilter_generator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as imageLib;
import 'package:path_provider/path_provider.dart';
import 'package:photofilters/filters/filters.dart';
import 'package:photofilters/filters/image_filters.dart';
import 'package:photofilters/filters/preset_filters.dart';
import 'package:photofilters/filters/subfilters.dart';
import 'package:photofilters/utils/image_filter_utils.dart'
    as image_filter_utils;
import 'dart:ui' as ui;

import 'package:photofilters/widgets/basic_tool_item.dart';

class PhotoFilter extends StatelessWidget {
  final imageLib.Image image;
  final String filename;
  final Filter filter;
  final BoxFit fit;
  final Widget loader;

  PhotoFilter({
    required this.image,
    required this.filename,
    required this.filter,
    this.fit = BoxFit.fill,
    this.loader = const Center(child: CircularProgressIndicator()),
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: compute(applyFilter, <String, dynamic>{
        "filter": filter,
        "image": image,
        "filename": filename,
      }),
      builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return loader;
          case ConnectionState.active:
          case ConnectionState.waiting:
            return loader;
          case ConnectionState.done:
            if (snapshot.hasError)
              return Center(child: Text('Error: ${snapshot.error}'));
            return Image.memory(
              snapshot.data as dynamic,
              fit: fit,
            );
        }
      },
    );
  }
}

///The PhotoFilterSelector Widget for apply filter from a selected set of filters
class PhotoFilterSelector extends StatefulWidget {
  final Widget title;
  final Color appBarColor;
  final List<Filter> filters;
  final imageLib.Image image;
  final Widget loader;
  final BoxFit fit;
  final String filename;
  final bool circleShape;
  final imageLib.Image? originalImage;
  final Filter? imageFilter;

  const PhotoFilterSelector({
    Key? key,
    required this.title,
    required this.filters,
    required this.image,
    this.appBarColor = Colors.blue,
    this.loader = const Center(child: CircularProgressIndicator()),
    this.fit = BoxFit.fill,
    required this.filename,
    this.imageFilter,
    this.originalImage,
    this.circleShape = false,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => new _PhotoFilterSelectorState();
}

class _PhotoFilterSelectorState extends State<PhotoFilterSelector> {
  String? filename;
  Map<String, List<int>?> cachedFilters = {};
  Filter? _filter;
  Filter? lastSelectedfilter;
  imageLib.Image? image;
  imageLib.Image? originalImage;
  GlobalKey globalKey = GlobalKey();
  late bool loading;
  List<BottomTabs> bottomTabs = [
    BottomTabs(title: "Filter", isSelected: true),
    BottomTabs(title: "Adjust", isSelected: false)
  ];
  BottomTabs selectedBottom = BottomTabs(title: "Filter", isSelected: true);
  double brightnessSliderValue = 0.0;
  double hueSliderValue = 0.0;
  double saturationSliderValue = 0.0;
  double contrastSliderValue = 0.0;
  double? lastBrightnessValue;
  double? lastHueValue;
  double? lastSaturationValue;
  double? lastContrastValue;

  List<BasicToolItemData> basicTools = [
    BasicToolItemData(title: 'Reset', iconData: Icons.refresh_sharp),
    BasicToolItemData(
        title: 'Brightness', iconData: Icons.brightness_2_outlined),
    BasicToolItemData(
      title: 'Hue',
      iconData: Icons.contrast_sharp,
    ),
    BasicToolItemData(
      title: 'Saturation',
      iconData: Icons.brightness_4,
    ),
    BasicToolItemData(
      title: 'Contrast',
      iconData: Icons.contrast_sharp,
    )
  ];
  BasicToolItemData? selectedBasicTool;

  @override
  void initState() {
    super.initState();
    loading = false;
    _filter = widget.imageFilter ?? widget.filters[0];
    filename = widget.filename;
    image = widget.image;
    originalImage = widget.originalImage;
    selectedBasicTool = basicTools[1];
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: widget.title,
          backgroundColor: widget.appBarColor,
          actions: <Widget>[
            loading
                ? Container()
                : IconButton(
                    icon: Icon(Icons.check),
                    onPressed: () async {
                      setState(() {
                        loading = true;
                      });
                      var file;
                      if (isBasicEdit()) {
                        RenderRepaintBoundary repaintBoundary =
                            globalKey.currentContext!.findRenderObject()
                                as RenderRepaintBoundary;
                        // repaintBoundary.size.
                        ui.Image boxImage =
                            await repaintBoundary.toImage(pixelRatio: 3);
                        ByteData? byteData = await boxImage.toByteData(
                            format: ui.ImageByteFormat.png);
                        Uint8List uint8list = byteData!.buffer.asUint8List();
                        File? pathOfImage;
                        final directory = await getTemporaryDirectory();
                        // await directory.createTemp("filtered");
                        pathOfImage = await File(
                                '${directory.path}/filtered_${_filter?.name ?? "_"}_$filename')
                            .create();
                        file = await pathOfImage.writeAsBytes(uint8list);
                      }
                      var imageFile = await saveFilteredImage();
                      Navigator.pop(context, {
                        'image_filtered': isBasicEdit() ? file : imageFile,
                        "filter": _filter,
                        "is_basic_edit": isBasicEdit()
                      });
                    },
                  )
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          child: loading
              ? widget.loader
              : Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      flex: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(25)),
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: GestureDetector(
                            onTapDown: (details) {
                              setState(() {
                                _filter = widget.filters[0];
                                brightnessSliderValue = 0.0;
                                hueSliderValue = 0.0;
                                contrastSliderValue = 0.0;
                                saturationSliderValue = 0.0;
                              });
                            },
                            onTapUp: (details) {
                              setState(() {
                                if (lastSelectedfilter != null) {
                                  _filter = lastSelectedfilter;
                                }
                                if (lastBrightnessValue != null) {
                                  brightnessSliderValue = lastBrightnessValue!;
                                }
                                if (lastHueValue != null) {
                                  hueSliderValue = lastHueValue!;
                                }
                                if (lastSaturationValue != null) {
                                  saturationSliderValue = lastSaturationValue!;
                                }
                                if (lastContrastValue != null) {
                                  contrastSliderValue = lastContrastValue!;
                                }
                              });
                            },
                            child: _buildFilteredImage(
                                _filter,
                                originalImage ?? image,
                                filename,
                                brightnessSliderValue),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ...List.generate(
                              bottomTabs.length,
                              (index) => BottomTabWidgets(
                                title: bottomTabs[index].title,
                                isSelected: bottomTabs[index].isSelected,
                                selectedColor: widget.appBarColor,
                                onTap: () {
                                  setState(() {
                                    bottomTabs.forEach((element) {
                                      element.isSelected = false;
                                    });
                                    bottomTabs[index].isSelected = true;
                                    selectedBottom = bottomTabs[index];
                                  });
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                        flex: 2,
                        child: selectedBottom.title == "Filter"
                            ? ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: widget.filters.length,
                                itemBuilder: (BuildContext context, int index) {
                                  return InkWell(
                                    child: Container(
                                      padding: EdgeInsets.all(5.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: <Widget>[
                                          _buildFilterThumbnail(
                                              widget.filters[index],
                                              originalImage ?? image,
                                              filename,
                                              _filter),
                                          SizedBox(
                                            height: 5.0,
                                          ),
                                          Text(
                                            widget.filters[index].name,
                                          )
                                        ],
                                      ),
                                    ),
                                    onTap: () => setState(() {
                                      _filter = widget.filters[index];
                                      lastSelectedfilter = _filter;
                                    }),
                                  );
                                },
                              )
                            : SingleChildScrollView(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        ...List.generate(
                                            basicTools.length,
                                            (index) => InkWell(
                                                  onTap: () {
                                                    if (index == 0) {
                                                      setState(() {
                                                        brightnessSliderValue =
                                                            0.0;
                                                        hueSliderValue = 0.0;
                                                        saturationSliderValue =
                                                            0.0;
                                                        contrastSliderValue =
                                                            0.0;
                                                      });
                                                    } else {
                                                      setState(() {
                                                        selectedBasicTool =
                                                            basicTools[index];
                                                      });
                                                    }
                                                  },
                                                  child: BasicToolItem(
                                                    data: basicTools[index],
                                                    selectedItem:
                                                        selectedBasicTool!,
                                                    selectedColor:
                                                        widget.appBarColor,
                                                  ),
                                                ))
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    getBasicSlider(selectedBasicTool!),
                                    SizedBox(height: 10),
                                  ],
                                ),
                              ))
                  ],
                ),
        ),
      ),
    );
  }

  bool isBasicEdit() {
    if (brightnessSliderValue != 0.0 ||
        saturationSliderValue != 0.0 ||
        hueSliderValue != 0.0) {
      return true;
    }
    return false;
  }

  Widget getBasicSlider(BasicToolItemData data) {
    if (data.title == "Brightness") {
      return Row(
        children: [
          Expanded(
            child: CustomSlider(
              sliderColor: widget.appBarColor,
              child: Slider(
                  max: 1.0,
                  min: -1.0,
                  divisions: 10,
                  value: brightnessSliderValue,
                  onChanged: (value) async {
                    setState(() {
                      if (value != brightnessSliderValue) {
                        brightnessSliderValue = value;
                        lastBrightnessValue = brightnessSliderValue;
                      }
                    });
                  }),
            ),
          ),
        ],
      );
    } else if (data.title == "Hue") {
      return Row(
        children: [
          Expanded(
            child: CustomSlider(
              sliderColor: widget.appBarColor,
              child: Slider(
                  max: 1.0,
                  min: -1.0,
                  divisions: 10,
                  value: hueSliderValue,
                  onChanged: (value) async {
                    setState(() {
                      if (value != hueSliderValue) {
                        hueSliderValue = value;
                        lastHueValue = hueSliderValue;
                      }
                    });
                  }),
            ),
          ),
        ],
      );
    } else if (data.title == "Saturation") {
      return Row(
        children: [
          Expanded(
            child: CustomSlider(
              sliderColor: widget.appBarColor,
              child: Slider(
                  max: 1.0,
                  min: -1.0,
                  divisions: 10,
                  value: saturationSliderValue,
                  onChanged: (value) async {
                    setState(() {
                      if (value != saturationSliderValue) {
                        saturationSliderValue = value;
                        lastSaturationValue = saturationSliderValue;
                      }
                    });
                  }),
            ),
          ),
        ],
      );
    } else if (data.title == "Contrast") {
      return Row(
        children: [
          Expanded(
            child: CustomSlider(
              sliderColor: widget.appBarColor,
              child: Slider(
                  max: 1.0,
                  min: -1.0,
                  divisions: 10,
                  value: contrastSliderValue,
                  onChanged: (value) async {
                    setState(() {
                      if (value != contrastSliderValue) {
                        contrastSliderValue = value;
                        lastContrastValue = contrastSliderValue;
                      }
                    });
                  }),
            ),
          ),
        ],
      );
    }
    return Container();
  }

  _buildFilterThumbnail(Filter filter, imageLib.Image? image, String? filename,
      Filter? selectedFilter) {
    bool isSelected = filter == selectedFilter;
    if (cachedFilters[filter.name] == null) {
      return FutureBuilder<List<int>>(
        future: compute(applyFilter, <String, dynamic>{
          "filter": filter,
          "image": image,
          "filename": filename,
        }),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.active:
            case ConnectionState.waiting:
              return CircleAvatar(
                radius: 50.0,
                child: Center(
                  child: widget.loader,
                ),
                backgroundColor: Colors.white,
              );
            case ConnectionState.done:
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              cachedFilters[filter.name] = snapshot.data;
              return Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50.0,
                    backgroundImage: MemoryImage(
                      snapshot.data as dynamic,
                    ),
                    backgroundColor: Colors.white,
                  ),
                  isSelected
                      ? Positioned.fill(
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withOpacity(.5),
                            radius: 50.0,
                            child: Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : SizedBox.shrink()
                ],
              );
          }
          // unreachable
        },
      );
    } else {
      return Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 50.0,
            backgroundImage: MemoryImage(
              cachedFilters[filter.name] as dynamic,
            ),
            backgroundColor: Colors.white,
          ),
          isSelected
              ? Positioned.fill(
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(.5),
                    radius: 50.0,
                    child: Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                    ),
                  ),
                )
              : SizedBox.shrink()
        ],
      );
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/filtered_${_filter?.name ?? "_"}_$filename');
  }

  Future<File> saveFilteredImage() async {
    var imageFile = await _localFile;
    await imageFile.writeAsBytes(cachedFilters[_filter?.name ?? "_"]!);
    return imageFile;
  }

  Widget _buildFilteredImage(Filter? filter, imageLib.Image? image,
      String? filename, double? brightness) {
    if (cachedFilters[filter?.name ?? "_"] == null) {
      return FutureBuilder<List<int>>(
        future: compute(applyFilter, <String, dynamic>{
          "filter": filter,
          "image": image,
          "filename": filename,
        }),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return widget.loader;
            case ConnectionState.active:
            case ConnectionState.waiting:
              return widget.loader;
            case ConnectionState.done:
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              cachedFilters[filter?.name ?? "_"] = snapshot.data;
              return widget.circleShape
                  ? SizedBox(
                      height: MediaQuery.of(context).size.width / 3,
                      width: MediaQuery.of(context).size.width / 3,
                      child: Center(
                        child: CircleAvatar(
                          radius: MediaQuery.of(context).size.width / 3,
                          backgroundImage: MemoryImage(
                            snapshot.data as dynamic,
                          ),
                        ),
                      ),
                    )
                  : Image.memory(
                      snapshot.data as dynamic,
                      fit: widget.fit,
                    );
          }
          // unreachable
        },
      );
    } else {
      return widget.circleShape
          ? SizedBox(
              height: MediaQuery.of(context).size.width / 3,
              width: MediaQuery.of(context).size.width / 3,
              child: Center(
                child: CircleAvatar(
                  radius: MediaQuery.of(context).size.width / 3,
                  backgroundImage: MemoryImage(
                    cachedFilters[filter?.name ?? "_"] as dynamic,
                  ),
                ),
              ),
            )
          : RepaintBoundary(
              key: globalKey,
              child: ImageFilter(
                brightness: brightnessSliderValue,
                hue: hueSliderValue,
                saturation: saturationSliderValue,
                contrast: contrastSliderValue,
                child: Image.memory(
                  cachedFilters[filter?.name ?? "_"] as dynamic,
                  fit: widget.fit,
                ),
              ),
            );
    }
  }
}

///The global applyfilter function
FutureOr<List<int>> applyFilter(Map<String, dynamic> params) {
  Filter? filter = params["filter"];
  imageLib.Image image = params["image"];
  String filename = params["filename"];
  List<int> _bytes = image.getBytes();
  if (filter != null) {
    filter.apply(_bytes as dynamic, image.width, image.height);
  }
  imageLib.Image _image =
      imageLib.Image.fromBytes(image.width, image.height, _bytes);
  _bytes = imageLib.encodeNamedImage(_image, filename)!;
  return _bytes;
}

///The global buildThumbnail function
FutureOr<List<int>> buildThumbnail(Map<String, dynamic> params) {
  int? width = params["width"];
  params["image"] = imageLib.copyResize(params["image"], width: width);
  return applyFilter(params);
}

Widget ImageFilter({brightness, saturation, hue, child, contrast}) {
  var bright = brightness.toStringAsFixed(1);
  var sat = saturation.toStringAsFixed(1);
  var hu = hue.toStringAsFixed(1);
  var cont = contrast.toStringAsFixed(1);
  return ColorFiltered(
      colorFilter: ColorFilter.matrix(
        ColorFilterAddons.brightness(double.parse(bright)),
      ),
      child: ColorFiltered(
          colorFilter: ColorFilter.matrix(
              ColorFilterAddons.saturation(double.parse(sat))),
          child: ColorFiltered(
            colorFilter:
                ColorFilter.matrix(ColorFilterAddons.hue(double.parse(hu))),
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(
                  ColorFilterAddons.contrast(double.parse(cont))),
              child: child,
            ),
          )));
}

class BottomTabWidgets extends StatelessWidget {
  const BottomTabWidgets(
      {Key? key,
      required this.title,
      required this.isSelected,
      this.selectedColor = Colors.green,
      this.nonSelectedColor = Colors.grey,
      required this.onTap})
      : super(key: key);
  final String title;
  final bool isSelected;
  final Color? selectedColor;
  final Color? nonSelectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(20),
          height: 60,
          alignment: Alignment.center,
          color: isSelected ? selectedColor : nonSelectedColor,
          width: MediaQuery.of(context).size.width,
          child: Text(
            title,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class BottomTabs {
  final String title;
  bool isSelected;

  BottomTabs({required this.title, required this.isSelected});
}

class CustomSlider extends StatelessWidget {
  const CustomSlider({Key? key, required this.child, required this.sliderColor})
      : super(key: key);
  final Widget child;
  final Color sliderColor;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
        data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            trackHeight: 14.0,
            inactiveTickMarkColor: Colors.black,
            activeTickMarkColor: Colors.black,
            tickMarkShape: LineSliderTickMarkShape(),
            thumbShape: SquareSliderComponentShape(color: sliderColor),
            overlayColor: Colors.transparent
            //     RoundSliderOverlayShape(
            //         overlayRadius: 20.0),
            ),
        child: child);
  }
}

class LineSliderTickMarkShape extends SliderTickMarkShape {
  const LineSliderTickMarkShape({
    this.tickMarkRadius,
  });

  final double? tickMarkRadius;

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) {
    assert(sliderTheme != null);
    assert(sliderTheme.trackHeight != null);
    assert(isEnabled != null);
    return Size.fromRadius(tickMarkRadius ?? sliderTheme.trackHeight! / 4);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    required bool isEnabled,
  }) {
    Color? begin;
    Color? end;
    switch (textDirection) {
      case TextDirection.ltr:
        final bool isTickMarkRightOfThumb = center.dx > thumbCenter.dx;
        begin = isTickMarkRightOfThumb
            ? sliderTheme.disabledInactiveTickMarkColor
            : sliderTheme.disabledActiveTickMarkColor;
        end = isTickMarkRightOfThumb
            ? sliderTheme.inactiveTickMarkColor
            : sliderTheme.activeTickMarkColor;
        break;
      case TextDirection.rtl:
        final bool isTickMarkLeftOfThumb = center.dx < thumbCenter.dx;
        begin = isTickMarkLeftOfThumb
            ? sliderTheme.disabledInactiveTickMarkColor
            : sliderTheme.disabledActiveTickMarkColor;
        end = isTickMarkLeftOfThumb
            ? sliderTheme.inactiveTickMarkColor
            : sliderTheme.activeTickMarkColor;
        break;
    }
    final Paint paint = Paint()
      ..color = ColorTween(begin: begin, end: end).evaluate(enableAnimation)!
      ..strokeWidth = 1;

    final double tickMarkRadius = getPreferredSize(
          isEnabled: isEnabled,
          sliderTheme: sliderTheme,
        ).width /
        2;

    context.canvas.drawLine(Offset(center.dx + 5, center.dy - 10),
        Offset(center.dx + 5, center.dy + 5), paint);
  }
}

class SquareSliderComponentShape extends SliderComponentShape {
  final Color color;

  SquareSliderComponentShape({required this.color});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(20, 30);
  }

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final Canvas canvas = context.canvas;
    var a = value < 0.5 ? 10 : 2;
    var b = value < 0.5 ? 5 : -7;
    String getValue(double value) {
      if (value == 0.5) {
        return "0";
      } else if (value < 0.5) {
        return "-${(value * 100).toStringAsFixed(0)}";
      } else {
        return "${(value * 100).toStringAsFixed(0)}";
      }
    }

    canvas.drawShadow(
        Path()
          ..addRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(center.dx + a, 20), width: 14, height: 30),
            const Radius.circular(4),
          )),
        Colors.black,
        5,
        false);
    TextSpan span = new TextSpan(
      style: new TextStyle(color: Colors.blue[800], fontSize: 11),
      text: "${(value * 100).toStringAsFixed(0)}",
    );
    TextPainter tp = new TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(center.dx + b, -10.0));
    // final bool isTickMarkRightOfThumb = center.dx > thumbCenter.dx;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(center.dx + a, 20), width: 10, height: 30),
        const Radius.circular(4),
      ),
      Paint()..color = color,
    );
  }
}
