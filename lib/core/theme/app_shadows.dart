import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  AppShadows._();

  static const raised = <BoxShadow>[
    BoxShadow(color: Color(0xBFFFFFFF), offset: Offset(-4, -4), blurRadius: 10),
    BoxShadow(color: Color(0x2634483A), offset: Offset(4, 4), blurRadius: 10),
    BoxShadow(color: Color(0x1434483A), offset: Offset(0, 0), blurRadius: 4),
  ];

  static const raisedDark = <BoxShadow>[
    BoxShadow(color: Color(0x263F5547), offset: Offset(-3, -3), blurRadius: 8),
    BoxShadow(color: Color(0x700A120D), offset: Offset(4, 4), blurRadius: 10),
  ];

  static const inset = <BoxShadow>[
    BoxShadow(color: Color(0x2634483A), offset: Offset(2, 2), blurRadius: 5),
    BoxShadow(color: Color(0xBFFFFFFF), offset: Offset(-2, -2), blurRadius: 5),
  ];

  static const border = Border.fromBorderSide(
    BorderSide(color: AppColors.border, width: 0.8),
  );
}
