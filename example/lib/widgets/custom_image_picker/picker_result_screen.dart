import 'package:flutter/material.dart';
import 'package:photofilters_example/widgets/custom_image_picker/src/insta_assets_crop_controller.dart';
import 'package:photofilters_example/widgets/selected_cropped_images.dart';

class PickerCropResultScreen extends StatelessWidget {
  const PickerCropResultScreen({super.key, required this.cropStream, this.frame = false});

  final Stream<InstaAssetsExportDetails> cropStream;
  final bool frame;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height - kToolbarHeight;

    return Scaffold(
      body: StreamBuilder<InstaAssetsExportDetails>(
          stream: cropStream,
          builder: (context, snapshot) {
            if (!snapshot.hasError &&
                snapshot.hasData &&
                snapshot.data!.croppedFiles.isNotEmpty) {
              return SelectedCroppedImages(
                croppedImages: snapshot.data?.croppedFiles ?? [],
                frame: frame,
              );
            } else {
              return Container();
            }
          }),
    );
  }
}
