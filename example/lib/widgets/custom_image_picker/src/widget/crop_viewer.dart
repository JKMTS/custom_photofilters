import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photofilters_example/widgets/custom_image_picker/insta_assets_picker.dart';
import 'package:photofilters_example/widgets/custom_image_picker/src/custom_packages/image_crop/crop.dart';
import 'package:photofilters_example/widgets/custom_image_picker/src/insta_assets_crop_controller.dart';
import 'package:photofilters_example/widgets/custom_image_picker/src/widget/circle_icon_button.dart';
import 'package:provider/provider.dart';
import 'package:extended_image/extended_image.dart';

class CropViewer extends StatefulWidget {
  const CropViewer({
    super.key,
    required this.provider,
    required this.textDelegate,
    required this.controller,
    required this.loaderWidget,
    required this.height,
    this.opacity = 1.0,
    this.theme,
    required this.cropEnabled,
  });

  final DefaultAssetPickerProvider provider;

  final AssetPickerTextDelegate textDelegate;

  final InstaAssetsCropController controller;

  final Widget loaderWidget;

  final double opacity;

  final double height;

  final bool cropEnabled;

  final ThemeData? theme;

  @override
  State<CropViewer> createState() => CropViewerState();
}

class CropViewerState extends State<CropViewer> {
  final _cropKey = GlobalKey<CropState>();
  AssetEntity? _previousAsset;
  final ValueNotifier<bool> _isLoadingError = ValueNotifier<bool>(false);
  AssetEntity? myAsset;
  @override
  void dispose() {
    _isLoadingError.dispose();
    super.dispose();
  }

  // @override
  // void initState(){
  //   WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
  //     if (!widget.cropEnabled) {
  //       debugPrint("inside the crop condition");
  //       Future.delayed(const Duration(milliseconds: 1000)).then((value) {
  //
  //         if(myAsset != null){
  //           debugPrint("inside the asset condition");
  //           setState(() {
  //             widget.controller.cusAspectRatio =
  //                 myAsset!.width / myAsset!.height;
  //           });
  //         }
  //       });
  //     }
  //   });
  //   super.initState();
  // }

  void saveCurrentCropChanges() {
    widget.controller.onChange(
      _previousAsset,
      _cropKey.currentState,
      widget.provider.selectedAssets,
    );
  }

  Widget _buildCropView(AssetEntity asset, CropInternal? cropParam) => Opacity(
        opacity: widget.controller.isCropViewReady.value ? widget.opacity : 1.0,
        child: Crop(
          key: _cropKey,
          image: AssetEntityImageProvider(asset, isOriginal: true),
          placeholderWidget: ValueListenableBuilder<bool>(
            valueListenable: _isLoadingError,
            builder: (context, isLoadingError, child) => Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: widget.opacity,
                  child: ExtendedImage(
                    // to match crop alignment
                    alignment: widget.controller.isSquare.value
                        ? Alignment.center
                        : Alignment.bottomCenter,
                    height: widget.height,
                    width: widget.height * widget.controller.cusAspectRatio,
                    image: AssetEntityImageProvider(asset, isOriginal: false),
                    enableMemoryCache: false,
                    // fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                    child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: widget.theme?.cardColor.withOpacity(0.4)),
                )),
                isLoadingError
                    ? Text(widget.textDelegate.loadFailed)
                    : widget.loaderWidget,
              ],
            ),
          ),
          onImageError: (exception, stackTrace) {
            widget.provider.unSelectAsset(asset);
            AssetEntityImageProvider(asset).evict();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _isLoadingError.value = true;
              widget.controller.isCropViewReady.value = true;
            });
          },
          onLoading: (isReady) => WidgetsBinding.instance.addPostFrameCallback(
              (_) => widget.controller.isCropViewReady.value = isReady),
          maximumScale: 10,
          aspectRatio: widget.controller.cusAspectRatio,
          disableResize: true,
          backgroundColor: widget.theme!.cardColor,
          initialParam: cropParam,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: MediaQuery.of(context).size.width,
      child: ValueListenableBuilder<AssetEntity?>(
        valueListenable: widget.controller.previewAsset,
        builder: (_, previewAsset, __) =>
            Selector<DefaultAssetPickerProvider, List<AssetEntity>>(
                selector: (_, DefaultAssetPickerProvider p) => p.selectedAssets,
                builder: (_, List<AssetEntity> selected, __) {
                  _isLoadingError.value = false;
                  final int effectiveIndex =
                      selected.isEmpty ? 0 : selected.indexOf(selected.last);

                  if (previewAsset == null && selected.isEmpty) {
                    return widget.loaderWidget;
                  }

                  final asset = previewAsset ?? selected[effectiveIndex];
                  final savedCropParam =
                      widget.controller.get(asset)?.cropParam;

                  if (asset != _previousAsset && _previousAsset != null) {
                    saveCurrentCropChanges();
                  }
                  myAsset = asset;
                  _previousAsset = asset;

                  return ValueListenableBuilder<bool>(
                    valueListenable: widget.controller.isSquare,
                    builder: (context, isSquare, child) => Stack(
                      children: [
                        Positioned.fill(
                          child: _buildCropView(asset, savedCropParam),
                        ),
                        widget.cropEnabled
                            ? Positioned(
                                left: 0,
                                bottom: 12,
                                child: Row(
                                  children: [
                                    CircleIconButton(
                                      onTap: () {
                                        setState(() {
                                          widget.controller.cusAspectRatio = 1;
                                        });
                                      },
                                      theme: widget.theme,
                                      icon: const Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 5),
                                        child: Text(
                                          "1 : 1",
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    CircleIconButton(
                                      onTap: () {
                                        setState(() {
                                          widget.controller.cusAspectRatio =
                                              4 / 5;
                                        });
                                      },
                                      theme: widget.theme,
                                      icon: const Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 5),
                                        child: Text(
                                          "4 : 5",
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    CircleIconButton(
                                      onTap: () {
                                        setState(() {
                                          widget.controller.cusAspectRatio =
                                              16 / 9;
                                        });
                                      },
                                      theme: widget.theme,
                                      icon: const Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 5),
                                        child: Text(
                                          "16 : 9",
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    CircleIconButton(
                                      onTap: () {
                                        setState(() {
                                          widget.controller.cusAspectRatio =
                                              asset.width / asset.height;
                                        });
                                      },
                                      theme: widget.theme,
                                      icon: const Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 5),
                                        child: Text(
                                          "Fit",
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : SizedBox.shrink(),
                      ],
                    ),
                  );
                }),
      ),
    );
  }
}
