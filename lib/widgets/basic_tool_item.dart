import 'package:flutter/material.dart';

class BasicToolItem extends StatelessWidget {
  const BasicToolItem(
      {Key? key,
      required this.data,
      required this.selectedItem,
      required this.selectedColor,
      this.unselectedColor = Colors.grey})
      : super(key: key);
  final BasicToolItemData data;
  final BasicToolItemData selectedItem;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    bool isSelected = selectedItem == data ? true : false;
    return Column(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: isSelected ? selectedColor : unselectedColor.withOpacity(.5),
          child: Icon(
            data.iconData,
            size: 30,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
        SizedBox(
          height: 5,
        ),
        Text(data.title)
      ],
    );
  }
}

class BasicToolItemData {
  final String title;
  final IconData iconData;

  BasicToolItemData(
      {required this.title, required this.iconData});
}
