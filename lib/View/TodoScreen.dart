// ignore_for_file: file_names

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:tasks/controllers/arrayController.dart';
import 'package:tasks/controllers/authController.dart';
import 'package:tasks/models/Todo.dart';
import 'package:tasks/services/functions.service.dart';
import 'package:tasks/services/notification.service.dart';
import 'package:tasks/services/database.service.dart';
import 'package:tasks/utils/global.dart';
import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tasks/utils/validators.dart';
import 'package:tasks/utils/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

final formKey = GlobalKey<FormState>();

class TodoScreen extends StatefulWidget {
  final int? todoIndex;
  final int? arrayIndex;

  const TodoScreen({Key? key, this.todoIndex, this.arrayIndex})
      : super(key: key);

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final ArrayController arrayController = Get.find();
  final AuthController authController = Get.find();
  final String uid = Get.find<AuthController>().user!.uid;
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late TextEditingController titleEditingController;
  late TextEditingController detailEditingController;

  late String _hour, _minute, _time;
  late String dateTime;
  late bool done;

  @override
  void initState() {
    super.initState();
    String title = '';
    String detail = '';
    String date = '';
    String? time = '';

    if (widget.todoIndex != null) {
      title = arrayController
              .arrays[widget.arrayIndex!].todos![widget.todoIndex!].title ??
          '';
      detail = arrayController
              .arrays[widget.arrayIndex!].todos![widget.todoIndex!].details ??
          '';
      date = arrayController
          .arrays[widget.arrayIndex!].todos![widget.todoIndex!].date!;
      time = arrayController
          .arrays[widget.arrayIndex!].todos![widget.todoIndex!].time;
    }

    _dateController = TextEditingController(text: date);
    _timeController = TextEditingController(text: time);
    titleEditingController = TextEditingController(text: title);
    detailEditingController = TextEditingController(text: detail);
    done = (widget.todoIndex == null)
        ? false
        : arrayController
            .arrays[widget.arrayIndex!].todos![widget.todoIndex!].done!;
  }

  @override
  void dispose() {
    super.dispose();
    titleEditingController.dispose();
    detailEditingController.dispose();
    _timeController.dispose();
    _dateController.dispose();
  }

  Future<void> _showDialog(Widget child) async {
    await showCupertinoModalPopup<void>(
        context: context,
        builder: (BuildContext context) => Container(
              height: 250,
              padding: const EdgeInsets.only(top: 6.0),
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: SafeArea(
                top: false,
                child: child,
              ),
            ));
  }

  DateTime selectedDate = DateTime.now();
  DateTime selectedTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      (DateTime.now().minute > 55)
          ? DateTime.now().hour + 1
          : DateTime.now().hour,
      (DateTime.now().minute > 55) ? 0 : DateTime.now().minute + 5);

  Future<void> _selectDate() async {
    await _showDialog(
      CupertinoDatePicker(
        initialDateTime: selectedDate,
        mode: CupertinoDatePickerMode.date,
        use24hFormat: false,
        onDateTimeChanged: (DateTime newDate) {
          setState(() => selectedDate = newDate);
        },
      ),
    );
  }

  Future<void> _selectTime() async {
    await _showDialog(
      CupertinoDatePicker(
        initialDateTime: DateTime(selectedDate.year, selectedDate.month,
            selectedDate.day, selectedTime.hour, selectedTime.minute),
        mode: CupertinoDatePickerMode.time,
        use24hFormat: false,
        onDateTimeChanged: (DateTime newTime) {
          setState(() => selectedTime = newTime);
        },
      ),
    );
  }

  Future _pickDateTime() async {
    DateTime? date = selectedDate;
    if (date == null) return;
    if (date != null) {
      selectedDate = date;
      _dateController.text = DateFormat("MM/dd/yyyy").format(selectedDate);
    }
    DateTime? time = selectedTime;
    if (time == null) {
      _timeController.text = formatDate(
          DateTime(
              DateTime.now().year,
              DateTime.now().day,
              DateTime.now().month,
              DateTime.now().hour,
              DateTime.now().minute + 5),
          [hh, ':', nn, " ", am]).toString();
    }
    if (time != null) {
      selectedTime = time;
      _hour = selectedTime.hour.toString();
      _minute = selectedTime.minute.toString();
      _time = '$_hour : $_minute';
      _timeController.text = _time;
      _timeController.text = formatDate(
          DateTime(2019, 08, 1, selectedTime.hour, selectedTime.minute),
          [hh, ':', nn, " ", am]).toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool visible =
        (_dateController.text.isEmpty && _timeController.text.isEmpty)
            ? false
            : true;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: CupertinoNavigationBar(
        backgroundColor: Colors.black,
        padding: EdgeInsetsDirectional.zero,
        leading: TextButton(
          style: const ButtonStyle(
            splashFactory: NoSplash.splashFactory,
          ),
          onPressed: () {
            Get.back();
          },
          child: Text(
            "Cancel",
            style: actionButtonTextStyle,
          ),
        ),
        middle: Text((widget.todoIndex == null) ? 'New Task' : 'Edit Task',
            style: menuTextStyle),
        trailing: TextButton(
          style: const ButtonStyle(
            splashFactory: NoSplash.splashFactory,
          ),
          onPressed: () async {
            if (widget.todoIndex == null && formKey.currentState!.validate()) {
              var finalId = UniqueKey().hashCode;
              arrayController.arrays[widget.arrayIndex!].todos!.add(Todo(
                  title: titleEditingController.text,
                  details: detailEditingController.text,
                  id: finalId,
                  date: _dateController.text,
                  time: _timeController.text,
                  dateAndTimeEnabled:
                      (_dateController.text != '' && _timeController.text != '')
                          ? true
                          : false,
                  done: false,
                  dateCreated: Timestamp.now()));
              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(uid)
                  .collection("arrays")
                  .doc(arrayController.arrays[widget.arrayIndex!].id)
                  .set({
                "title": arrayController.arrays[widget.arrayIndex!].title,
                "dateCreated":
                    arrayController.arrays[widget.arrayIndex!].dateCreated,
                "todos": arrayController.arrays[widget.arrayIndex!].todos!
                    .map((todo) => todo.toJson())
                    .toList()
              });
              Database().addAllTodo(
                  uid,
                  finalId,
                  arrayController.arrays[widget.arrayIndex!].title!,
                  titleEditingController.text,
                  detailEditingController.text,
                  Timestamp.now(),
                  _dateController.text,
                  _timeController.text,
                  false,
                  (_dateController.text != '' && _timeController.text != '')
                      ? true
                      : false,
                  finalId);
              Get.back();
              HapticFeedback.heavyImpact();
              if (_dateController.text.isNotEmpty &&
                  _timeController.text.isNotEmpty) {
                NotificationService().showNotification(
                    finalId,
                    'Reminder',
                    titleEditingController.text,
                    Functions.parse(
                        _dateController.text, _timeController.text));
              }
              NotificationService().showNotification(
                  0, 'test', 'test', tz.TZDateTime.from(DateTime.now().add(Duration(seconds: 10)), tz.local));
            }
            if (widget.todoIndex != null && formKey.currentState!.validate()) {
              var editing = arrayController
                  .arrays[widget.arrayIndex!].todos![widget.todoIndex!];
              editing.title = titleEditingController.text;
              editing.details = detailEditingController.text;
              editing.date = _dateController.text;
              editing.time = _timeController.text;
              editing.done = done;
              editing.dateAndTimeEnabled = (titleEditingController.text != '' &&
                      detailEditingController.text != '')
                  ? true
                  : false;
              arrayController.arrays[widget.arrayIndex!]
                  .todos![widget.todoIndex!] = editing;
              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(uid)
                  .collection("arrays")
                  .doc(arrayController.arrays[widget.arrayIndex!].id)
                  .set({
                "title": arrayController.arrays[widget.arrayIndex!].title,
                "dateCreated":
                    arrayController.arrays[widget.arrayIndex!].dateCreated,
                "todos": arrayController.arrays[widget.arrayIndex!].todos!
                    .map((todo) => todo.toJson())
                    .toList()
              });
              Database().updateAllTodo(
                  uid,
                  arrayController.arrays[widget.arrayIndex!]
                      .todos![widget.todoIndex!].id!, // get doc id
                  arrayController.arrays[widget.arrayIndex!].title!,
                  titleEditingController.text,
                  detailEditingController.text,
                  Timestamp.now(),
                  _dateController.text,
                  _timeController.text,
                  done,
                  (_dateController.text != '' && _timeController.text != '')
                      ? true
                      : false,
                  arrayController.arrays[widget.arrayIndex!]
                      .todos![widget.todoIndex!].id!);
              Get.back();
              HapticFeedback.heavyImpact();
              if (_dateController.text.isNotEmpty &&
                  _timeController.text.isNotEmpty) {
                NotificationService().flutterLocalNotificationsPlugin.cancel(
                    arrayController.arrays[widget.arrayIndex!]
                        .todos![widget.todoIndex!].id!);
                NotificationService().showNotification(
                    arrayController.arrays[widget.arrayIndex!]
                        .todos![widget.todoIndex!].id!,
                    'Reminder',
                    titleEditingController.text,
                    Functions.parse(
                        _dateController.text, _timeController.text));
              } else {
                NotificationService().flutterLocalNotificationsPlugin.cancel(
                    arrayController.arrays[widget.arrayIndex!]
                        .todos![widget.todoIndex!].id!);
              }
            }
          },
          child: Text((widget.todoIndex == null) ? 'Add' : 'Update',
              style: paragraphPrimary),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity,
            padding: (MediaQuery.of(context).size.width < 768)
                ? const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0)
                : const EdgeInsets.symmetric(horizontal: 35.0, vertical: 15.0),
            child: Column(
              children: [
                Container(
                    decoration: BoxDecoration(
                        color: tertiaryColor,
                        borderRadius: BorderRadius.circular(14.0)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 15.0),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                              validator: Validator.titleValidator,
                              controller: titleEditingController,
                              autofocus: true,
                              autocorrect: false,
                              cursorColor: Colors.grey,
                              maxLines: 1,
                              maxLength: 25,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                  counterStyle: counterTextStyle,
                                  hintStyle: hintTextStyle,
                                  hintText: "Title",
                                  border: InputBorder.none),
                              style: todoScreenStyle),
                          primaryDivider,
                          TextField(
                              controller: detailEditingController,
                              maxLines: null,
                              autocorrect: false,
                              cursorColor: Colors.grey,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                  counterStyle: counterTextStyle,
                                  hintStyle: hintTextStyle,
                                  hintText: "Notes",
                                  border: InputBorder.none),
                              style: todoScreenDetailsStyle),
                        ],
                      ),
                    )),
                Visibility(
                  visible: (widget.todoIndex != null) ? true : false,
                  child: Container(
                      margin: const EdgeInsets.only(top: 20.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: tertiaryColor,
                          borderRadius: BorderRadius.circular(14.0)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 20.0),
                      child: GestureDetector(
                        onTap: () {},
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Completed",
                              style: todoScreenStyle,
                            ),
                            Transform.scale(
                              scale: 1.3,
                              child: Theme(
                                  data: ThemeData(
                                      unselectedWidgetColor:
                                          const Color.fromARGB(
                                              255, 187, 187, 187)),
                                  child: Checkbox(
                                      shape: const CircleBorder(),
                                      checkColor: Colors.white,
                                      activeColor: primaryColor,
                                      value: done,
                                      side:
                                          Theme.of(context).checkboxTheme.side,
                                      onChanged: (value) {
                                        setState(() {
                                          done = value!;
                                        });
                                      })),
                            )
                          ],
                        ),
                      )),
                ),
                GestureDetector(
                  onTap: () async {
                    await _selectDate();
                    await _selectTime();
                    await _pickDateTime();
                    setState(() {
                      visible = true;
                    });
                  },
                  child: Container(
                      margin: const EdgeInsets.only(top: 20.0),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 15.0),
                      decoration: BoxDecoration(
                          color: tertiaryColor,
                          borderRadius: BorderRadius.circular(14.0)),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: TextField(
                                  enabled: false,
                                  controller: _dateController,
                                  onChanged: (String val) {},
                                  decoration: InputDecoration(
                                      hintText: "Date",
                                      hintStyle: hintTextStyle,
                                      border: InputBorder.none),
                                  style: todoScreenStyle,
                                ),
                              ),
                              visible
                                  ? IconButton(
                                      onPressed: () {
                                        _dateController.clear();
                                        _timeController.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                      ))
                                  : Container()
                            ],
                          ),
                          primaryDivider,
                          TextField(
                            onChanged: (String val) {},
                            enabled: false,
                            controller: _timeController,
                            decoration: InputDecoration(
                                hintText: "Enter",
                                hintStyle: hintTextStyle,
                                border: InputBorder.none),
                            style: todoScreenStyle,
                          )
                        ],
                      )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
