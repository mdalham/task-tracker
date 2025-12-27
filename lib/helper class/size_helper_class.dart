import 'package:flutter/material.dart';

class SizeHelperClass {


  //Task search icon
  static double searchIconHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.05;
  static double searchIconWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.05;
  static double sortIconHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.0325;
  static double sortIconWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.065;

//Task reminder icon
  static double reminderIconHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.022;
  static double reminderIconWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.025;

  //List tile icon
  static double listIconHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.0325;
  static double listIconWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.065;

  //List tile container
  static double listIconContainerHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.054;
  static double listIconContainerWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.12;

  //Circular check box icon
  static double circularCheckboxHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.05;
  static double circularCheckboxWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.05;

  //More icon
  static double moreIconHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.028;
  static double moreIconWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.3;

  //CalendarDay icon
  static double calendarDayHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.018;
  static double calendarDayWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.018;

  static double repeatTaskIconHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.05;
  static double repeatTaskIconWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.05;

  //Setting screen list icon
  static double settingSLIconHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.025;
  static double settingSLIconWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.04;

  //Notification list icon
  static double notificationLIconHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.025;
  static double notificationLIconWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.04;

  static double loginIconHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.04;
  static double loginLIconWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.04;

  //Keyboard Arrow Down Icon Size
  static double keyboardArrowDownIconSize(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide * 0.07;

  static double reminderIconSize(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide * 0.065;

  static double repeatTaskIconSize(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide * 0.05;

  //Home container shrink height
  static double homeConSHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.131;

  //Home container expended height
  static double homeConEHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.47;

  static double noteAddAppIconHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.03;
  static double noteAddAppIconWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.032;

  static double conMinHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.37;

}
