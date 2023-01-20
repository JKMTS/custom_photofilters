// ignore_for_file: implementation_imports

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:photofilters_example/widgets/custom_image_picker/insta_assets_picker.dart';
import 'package:photofilters_example/widgets/custom_image_picker/src/insta_assets_crop_controller.dart';
import 'package:photofilters_example/widgets/custom_image_picker/src/widget/circle_icon_button.dart';
import 'package:photofilters_example/widgets/custom_image_picker/src/widget/crop_viewer.dart';
import 'package:provider/provider.dart';

import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_assets_picker/src/widget/platform_progress_indicator.dart';

/// The reduced height of the crop view
const _kReducedCropViewHeight = kToolbarHeight;

/// The position of the crop view when extended
const _kExtendedCropViewPosition = 0.0;

/// Scroll offset multiplier to start viewer position animation
const _kScrollMultiplier = 1.5;

const _kIndicatorSize = 20.0;
const _kPathSelectorRowHeight = 50.0;

class InstaAssetPickerBuilder extends DefaultAssetPickerBuilderDelegate {
  InstaAssetPickerBuilder({
    required super.provider,
    required this.onCompleted,
    required this.cropEnabled,
    super.gridCount = 4,
    super.pickerTheme,
    super.textDelegate,
    super.locale,
    super.keepScrollOffset,
    super.loadingIndicatorBuilder,
    this.title,
    this.closeOnComplete = false,
  }) : super(
          shouldRevertGrid: false,
          initialPermission: PermissionState.authorized,
          specialItemPosition: SpecialItemPosition.none,
        );

  final String? title;

  final Function(Stream<InstaAssetsExportDetails>) onCompleted;

  /// Should the picker be closed when the selection is confirmed
  ///
  /// Defaults to `false`, like instagram
  final bool closeOnComplete;

  // LOCAL PARAMETERS

  final bool cropEnabled;

  /// Save last position of the grid view scroll controller
  double _lastScrollOffset = 0.0;
  double _lastEndScrollOffset = 0.0;

  /// Scroll offset position to jump to after crop view is expanded
  double? _scrollTargetOffset;

  final ValueNotifier<double> _cropViewPosition = ValueNotifier<double>(0);
  final _cropViewerKey = GlobalKey<CropViewerState>();
  late final _cropController = InstaAssetsCropController(keepScrollOffset);

  @override
  void initState(AssetPickerState<AssetEntity, AssetPathEntity> state) {
    super.initState(state);
  }

  @override
  void dispose() {
    if (!keepScrollOffset) {
      _cropController.dispose();
      _cropViewPosition.dispose();
    }
    super.dispose();
  }

  void onConfirm(BuildContext context) {
    if (closeOnComplete) {
      Navigator.of(context).maybePop(provider.selectedAssets);
    }
    _cropViewerKey.currentState?.saveCurrentCropChanges();
    onCompleted(_cropController.exportCropFiles(provider.selectedAssets));
  }

  /// The responsive height of the crop view
  /// setup to not be bigger than half the screen height
  double cropViewHeight(BuildContext context) => math.min(
        MediaQuery.of(context).size.width,
        MediaQuery.of(context).size.height * 0.5,
      );

  /// Returns thumbnail [index] position in scroll view
  double indexPosition(BuildContext context, int index) {
    final row = (index / gridCount).floor();
    final size =
        (MediaQuery.of(context).size.width - itemSpacing * (gridCount - 1)) /
            gridCount;
    return row * size + (row * itemSpacing);
  }

  void _expandCropView([double? lockOffset]) {
    _scrollTargetOffset = lockOffset;
    _cropViewPosition.value = _kExtendedCropViewPosition;
  }

  void unSelectAll() {
    provider.selectedAssets = [];
    _cropController.clear();
  }

  /// Initialize [previewAsset] with [p.selectedAssets] if not empty
  /// otherwise if the first item of the album
  Future<void> _initializePreviewAsset(
    DefaultAssetPickerProvider p,
    bool shouldDisplayAssets,
    BuildContext context,
  ) async {
    if (_cropController.previewAsset.value != null) return;

    if (p.selectedAssets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _cropController.previewAsset.value = p.selectedAssets.last);
    }

    // when asset list is available and no asset is selected,
    // preview the first of the list
    if (shouldDisplayAssets && p.selectedAssets.isEmpty) {
      debugPrint("inside the condition AAAAAAAAAA");
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        debugPrint("isnide the post frame back BBBBBBBB");
        final list =
            await p.currentPath?.path.getAssetListRange(start: 0, end: 1);
        if (list?.isNotEmpty ?? false) {
          _cropController.previewAsset.value = list!.first;
          p.selectedAssets = [];
          if (p.selectedAssets.isEmpty) {
            p.selectedAssets.add(_cropController.previewAsset.value!);
            _cropController.cusAspectRatio =
                p.selectedAssets[0].width / p.selectedAssets[0].height;
          }
        }
      });
    }
  }

  @override
  Future<void> viewAsset(
    BuildContext context,
    int index,
    AssetEntity currentAsset,
  ) async {
    if (_cropController.isCropViewReady.value != true) {
      return;
    }

    // if is preview asset, unselect it
    if (provider.selectedAssets.isNotEmpty &&
        _cropController.previewAsset.value == currentAsset) {
      selectAsset(context, currentAsset, index, true);
      _cropController.previewAsset.value = provider.selectedAssets.isEmpty
          ? currentAsset
          : provider.selectedAssets.last;
      return;
    }

    _cropController.previewAsset.value = currentAsset;
    selectAsset(context, currentAsset, index, false);
  }

  @override
  Future<void> selectAsset(
    BuildContext context,
    AssetEntity asset,
    int index,
    bool selected,
  ) async {
    if (_cropController.isCropViewReady.value != true) {
      return;
    }

    final thumbnailPosition = indexPosition(context, index);
    final prevCount = provider.selectedAssets.length;
    await super.selectAsset(context, asset, index, selected);

    // update preview asset with selected
    final selectedAssets = provider.selectedAssets;
    if (prevCount < selectedAssets.length) {
      _cropController.previewAsset.value = asset;
    } else if (selected &&
        asset == _cropController.previewAsset.value &&
        selectedAssets.isNotEmpty) {
      _cropController.previewAsset.value = selectedAssets.last;
    }

    _expandCropView(thumbnailPosition);
  }

  /// Handle scroll on grid view to hide/expand the crop view
  bool _handleScroll(
    BuildContext context,
    ScrollNotification notification,
    double position,
    double reducedPosition,
  ) {
    if (gridScrollController.position.pixels == 0) {
      _cropViewPosition.value = 0;
    }
    final isScrollUp = gridScrollController.position.userScrollDirection ==
        ScrollDirection.reverse;
    final isScrollDown = gridScrollController.position.userScrollDirection ==
        ScrollDirection.forward;

    if (notification is ScrollEndNotification) {
      _lastEndScrollOffset = gridScrollController.offset;
      // reduce crop view
      if (position > reducedPosition && position < _kExtendedCropViewPosition) {
        _cropViewPosition.value = reducedPosition;
        return true;
      }
    }

    // expand crop view
    if (isScrollDown &&
        gridScrollController.offset < 0 &&
        position < _kExtendedCropViewPosition) {
      // if scroll at edge, compute position based on scroll
      if (_lastScrollOffset > gridScrollController.offset) {
        _cropViewPosition.value -=
            (_lastScrollOffset.abs() - gridScrollController.offset.abs()) * 6;
      } else {
        // otherwise just expand it
        _expandCropView();
      }
    } else if (isScrollUp &&
        (gridScrollController.offset - _lastEndScrollOffset) *
                _kScrollMultiplier >
            cropViewHeight(context) - position &&
        position > reducedPosition) {
      // reduce crop view
      _cropViewPosition.value = cropViewHeight(context) -
          (gridScrollController.offset - _lastEndScrollOffset) *
              _kScrollMultiplier;
      if (gridScrollController.position.atEdge) {}
    }

    _lastScrollOffset = gridScrollController.offset;

    return true;
  }

  /// Returns a loader [Widget] to show in crop view and instead of confirm button
  Widget _buildLoader(BuildContext context, double radius) {
    if (super.loadingIndicatorBuilder != null) {
      return super.loadingIndicatorBuilder!(context, provider.isAssetsEmpty);
    }
    return PlatformProgressIndicator(
      radius: radius,
      size: radius * 2,
      color: theme.iconTheme.color,
    );
  }

  @override
  Widget pathEntitySelector(BuildContext context) {
    Widget selector(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4)
            .copyWith(top: 8, bottom: 12),
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: theme.splashColor,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4).copyWith(left: 6),
          ),
          onPressed: () {
            Feedback.forTap(context);
            isSwitchingPath.value = !isSwitchingPath.value;
          },
          child: Selector<DefaultAssetPickerProvider,
              PathWrapper<AssetPathEntity>?>(
            selector: (_, DefaultAssetPickerProvider p) => p.currentPath,
            builder: (_, PathWrapper<AssetPathEntity>? p, Widget? w) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (p != null)
                  Flexible(
                    child: Text(
                      isPermissionLimited && p.path.isAll
                          ? textDelegate.accessiblePathName
                          : p.path.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                w!,
              ],
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: isSwitchingPath,
              builder: (_, bool isSwitchingPath, Widget? w) => Transform.rotate(
                angle: isSwitchingPath ? math.pi : 0,
                child: w,
              ),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: theme.iconTheme.color,
              ),
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<DefaultAssetPickerProvider>.value(
      value: provider,
      builder: (BuildContext c, _) => selector(c),
    );
  }

  @override
  Widget confirmButton(BuildContext context) {
    final Widget button = ValueListenableBuilder<bool>(
      valueListenable: _cropController.isCropViewReady,
      builder: (_, isLoaded, __) => Consumer<DefaultAssetPickerProvider>(
        builder: (_, DefaultAssetPickerProvider p, __) {
          return TextButton(
            style: TextButton.styleFrom(
              foregroundColor:
                  p.isSelectedNotEmpty ? themeColor : theme.dividerColor,
            ),
            onPressed: isLoaded && p.isSelectedNotEmpty
                ? () => onConfirm(context)
                : null,
            child: isLoaded
                ? Text(
                    p.isSelectedNotEmpty && !isSingleAssetMode
                        ? '${textDelegate.confirm}'
                            ' (${p.selectedAssets.length}/${p.maxAssets})'
                        : textDelegate.confirm,
                  )
                : _buildLoader(context, 10),
          );
        },
      ),
    );
    return ChangeNotifierProvider<DefaultAssetPickerProvider>.value(
      value: provider,
      builder: (_, __) => button,
    );
  }

  @override
  Widget androidLayout(BuildContext context) {
    // height of appbar + cropview + path selector row
    final topWidgetHeight = cropViewHeight(context) +
        kToolbarHeight +
        _kPathSelectorRowHeight +
        MediaQuery.of(context).padding.top;

    return ChangeNotifierProvider<DefaultAssetPickerProvider>.value(
      value: provider,
      builder: (context, _) => ValueListenableBuilder<double>(
          valueListenable: _cropViewPosition,
          builder: (context, position, child) {
            // the top position when the crop view is reduced
            final topReducedPosition = -(cropViewHeight(context) -
                _kReducedCropViewHeight +
                kToolbarHeight);
            position =
                position.clamp(topReducedPosition, _kExtendedCropViewPosition);
            // the height of the crop view visible on screen
            final cropViewVisibleHeight = (topWidgetHeight +
                    position -
                    MediaQuery.of(context).padding.top -
                    kToolbarHeight -
                    _kPathSelectorRowHeight)
                .clamp(_kReducedCropViewHeight, topWidgetHeight);
            // opacity is calculated based on the position of the crop view
            final opacity =
                ((position / -topReducedPosition) + 1).clamp(0.4, 1.0);
            final animationDuration = position == topReducedPosition ||
                    position == _kExtendedCropViewPosition
                ? const Duration(milliseconds: 250)
                : Duration.zero;

            double gridHeight = MediaQuery.of(context).size.height -
                kToolbarHeight -
                _kReducedCropViewHeight;
            // when not assets are displayed, compute the exact height to show the loader
            if (!provider.hasAssetsToDisplay) {
              gridHeight -= cropViewHeight(context) - -_cropViewPosition.value;
            }
            final topPadding = topWidgetHeight + position;
            if (gridScrollController.hasClients &&
                _scrollTargetOffset != null) {
              gridScrollController.jumpTo(_scrollTargetOffset!);
            }
            _scrollTargetOffset = null;

            return Stack(
              children: [
                AnimatedPadding(
                  padding: EdgeInsets.only(top: topPadding),
                  duration: animationDuration,
                  child: SizedBox(
                    height: gridHeight,
                    width: MediaQuery.of(context).size.width,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        return _handleScroll(
                          context,
                          notification,
                          position,
                          topReducedPosition,
                        );
                      },
                      child: _buildGrid(context),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  top: position,
                  duration: animationDuration,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: topWidgetHeight,
                    child: AssetPickerAppBarWrapper(
                      appBar: AssetPickerAppBar(
                        title: title != null
                            ? Text(
                                title!,
                                style: Theme.of(context).textTheme.titleLarge,
                              )
                            : null,
                        leading: backButton(context),
                        actions: <Widget>[confirmButton(context)],
                      ),
                      body: DecoratedBox(
                        decoration: BoxDecoration(
                          color: pickerTheme?.canvasColor,
                        ),
                        child: Column(
                          children: [
                            Listener(
                              onPointerDown: (_) {
                                _expandCropView();
                                // stop scroll event
                                if (gridScrollController.hasClients) {
                                  gridScrollController
                                      .jumpTo(gridScrollController.offset);
                                }
                              },
                              child: CropViewer(
                                key: _cropViewerKey,
                                controller: _cropController,
                                textDelegate: textDelegate,
                                provider: provider,
                                opacity: opacity,
                                height: cropViewHeight(context),
                                // center the loader in the visible viewport of the crop view
                                loaderWidget: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox(
                                    height: cropViewVisibleHeight,
                                    child: Center(
                                      child: _buildLoader(context, 16),
                                    ),
                                  ),
                                ),
                                theme: pickerTheme,
                                cropEnabled: cropEnabled,
                              ),
                            ),
                            SizedBox(
                              height: _kPathSelectorRowHeight,
                              width: MediaQuery.of(context).size.width,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  pathEntitySelector(context),
                                  CircleIconButton(
                                    onTap: unSelectAll,
                                    theme: pickerTheme,
                                    icon: const Icon(
                                      Icons.layers_clear_sharp,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                pathEntityListBackdrop(context),
                _buildListAlbums(context),
              ],
            );
          }),
    );
  }

  @override
  Widget appleOSLayout(BuildContext context) => androidLayout(context);

  Widget _buildListAlbums(context) {
    return Consumer<DefaultAssetPickerProvider>(
        builder: (BuildContext context, provider, __) {
      if (isAppleOS) return pathEntityListWidget(context);

      // NOTE: fix position on android, quite hacky could be optimized
      return ValueListenableBuilder<bool>(
        valueListenable: isSwitchingPath,
        builder: (_, bool isSwitchingPath, Widget? child) =>
            Transform.translate(
          offset: isSwitchingPath
              ? Offset(0, kToolbarHeight + MediaQuery.of(context).padding.top)
              : Offset.zero,
          child: Stack(
            children: [pathEntityListWidget(context)],
          ),
        ),
      );
    });
  }

  Widget _buildGrid(BuildContext context) {
    return Consumer<DefaultAssetPickerProvider>(
      builder: (BuildContext context, DefaultAssetPickerProvider p, __) {
        final bool shouldDisplayAssets =
            p.hasAssetsToDisplay || shouldBuildSpecialItem;
        _initializePreviewAsset(p, shouldDisplayAssets, context);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: shouldDisplayAssets
              ? MediaQuery(
                  // fix: https://github.com/fluttercandies/flutter_wechat_assets_picker/issues/395
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: -kToolbarHeight),
                  ),
                  child: RepaintBoundary(child: assetsGridBuilder(context)),
                )
              : loadingIndicator(context),
        );
      },
    );
  }

  /// To show selected assets indicator and preview asset overlay
  @override
  Widget selectIndicator(BuildContext context, int index, AssetEntity asset) {
    final selectedAssets = provider.selectedAssets;
    final Duration duration = switchingPathDuration * 0.75;

    final int indexSelected = selectedAssets.indexOf(asset);
    final bool isSelected = indexSelected != -1;

    final Widget innerSelector = AnimatedContainer(
      duration: duration,
      width: _kIndicatorSize,
      height: _kIndicatorSize,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.selectedRowColor, width: 1),
        color: isSelected ? themeColor : theme.selectedRowColor.withOpacity(.2),
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        child: AnimatedSwitcher(
          duration: duration,
          reverseDuration: duration,
          child: isSelected
              ? Text((indexSelected + 1).toString())
              : const SizedBox.shrink(),
        ),
      ),
    );

    return ValueListenableBuilder<AssetEntity?>(
      valueListenable: _cropController.previewAsset,
      builder: (context, previewAsset, child) {
        final bool isPreview = asset == _cropController.previewAsset.value;

        return Positioned.fill(
          child: GestureDetector(
            onTap: () {
              if (isPreviewEnabled) {
                debugPrint("inside when adding the image to list");
                viewAsset(context, index, asset);
              }
              _cropController.cusAspectRatio = asset.width / asset.height;
            },
            child: AnimatedContainer(
              duration: switchingPathDuration,
              padding: const EdgeInsets.all(4),
              color: isPreview
                  ? theme.selectedRowColor.withOpacity(.5)
                  : theme.backgroundColor.withOpacity(.1),
              child: Align(
                alignment: AlignmentDirectional.topEnd,
                child: isSelected && !isSingleAssetMode
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            selectAsset(context, asset, index, isSelected),
                        child: innerSelector,
                      )
                    : innerSelector,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget selectedBackdrop(BuildContext context, int index, AssetEntity asset) =>
      const SizedBox.shrink();
}
