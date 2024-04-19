import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:sprintf/sprintf.dart';

/*
 * @description Helper
 * @author zl
 * @date 2024/4/18 16:10
 */
class Helper extends ChangeNotifier {
  static final Helper h = Helper._();

  Helper._();

  List<int> bufferArray = [];
  int hr = 0; //Heart Rate
  int sys = 0; //Systolic Blood Pressure
  int dia = 0; //Diastolic Blood Pressure
  double map = 0.0;//Average pressure
  int spo2 = 0; //Oxygen Saturation
  int pr = 0; //Pulse Rate
  double temp = 0.0; //Temperature
  int resp = 0; //Respiratory Rate
  bool bodyTemp = false; //Body temperature measurement
  bool isEcgPeak = false; //Whether there is an ECG lead

  int battery = 0;
  String deviceName = '--';
  String deviceId = '--';

  Timer? timer;

  void init() {
    bufferArray = [];
    hr = 0;
    sys = 0;
    dia = 0;
    map = 0.0;
    spo2 = 0;
    pr = 0;
    temp = 0.0;
    resp = 0;
    bodyTemp = false;
    isEcgPeak = false;
    battery = 0;
    deviceName = '--';
    deviceId = '--';
    refresh();
  }

  void analysis(List<int> array) {
    bufferArray += array;
    var i = 0; //Current index
    var validIndex = 0; //Valid indexes
    var maxIndex = bufferArray.length - 7; //Leave at least enough room for a minimum set of data
    while (i <= maxIndex) {
      //Failed to match the headers
      if (bufferArray[i] != 0x55 || bufferArray[i + 1] != 0xAA) {
        i += 1;
        validIndex = i;
        continue;
      }
      var length = bufferArray[i + 2]; //The data header is successfully matched
      var type = bufferArray[i + 3]; //Packet type
      var dataCount = length - 3; //The amount of valid data
      var packageLength = length + 2; //Package length

      //If no valid data is obtained, skip 2 to avoid missing valid data
      if (dataCount <= 0) {
        i += 2;
        validIndex = i;
        continue;
      }
      //If the remaining data length is less than the data length of the current group, you do not need to process it in this cycle
      if (i + packageLength > bufferArray.length) {
        validIndex = i;
        break;
      }
      var checkSum = bufferArray[i + 4 + dataCount] & 0xFF; //The packet check digit, which is taken after 8 digits
      var sum = 0;
      List<num> array = [];
      for (int index = 0; index < dataCount; index++) {
        var value = bufferArray[i + 4 + index];
        sum += value;
        array.add(value);
      }
      //Check whether the data is incorrect
      var realSum = (~(length + type + sum)) & 0xFF; //The decimal values are added to the inverse digits, and the last 8 digits are taken
      if (checkSum != realSum) {
        i += 2; //If no valid data is obtained, skip 2 to avoid missing valid data
        validIndex = i;
        continue;
      }
      //The verification is successful
      _readData(type, array);

      i += packageLength; //Get valid data, skip one set of data, and detect the next set of data
      validIndex = i;
      continue;
    }
    //The array before the valid index belongs to the scanned and is not needed, and it is directly emptied
    bufferArray = bufferArray.sublist(validIndex); //Reorganize the cache array, delete all the data before the valid index
  }

  //Read the data
  void _readData(int type, List<num> array) {
    switch (type) {
      case 0x01:
        _ecgWave(array);
        break;
      case 0x02:
        _hrResp(array);
        break;
      case 0x03:
        _nibp(array);
        break;
      case 0x04:
        _spo2Pr(array);
        break;
      case 0x05:
        _temp(array);
        break;
      case 0xFE:
        _spo2Wave(array);
        break;
      case 0xFF:
        _respWave(array);
        break;
      case 0x30:
        _ecgPeak(array);
        break;
      case 0x31:
        _spo2Peak(array);
        break;
      case 0xB0:
        _battery(array);
        break;
    }
    refresh();
  }

  //Start the pet monitor refresh interface
  void startTimer() {
    stopTimer();
    //Refresh every second
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      refresh();
    });
  }

  //Stop the timer
  void stopTimer() {
    timer?.cancel();
    timer = null;
  }

  //Set device information
  void setDeviceInfo(DiscoveredDevice device) {
    deviceName = _setBleName(device.name);
    deviceId = _getMac(device);
    refresh();
  }

  ///Get Mac, iOS compatible
  String _getMac(DiscoveredDevice device) {
    var manufacturerData = device.manufacturerData.toList();
    if (manufacturerData.length >= 8) {
      var mac = manufacturerData
          .sublist(2, 8)
          .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
          .toList();
      return sprintf('%s:%s:%s:%s:%s:%s', mac).toString();
    }
    return device.id.startsWith('00:A0:50') ? device.id : '--';
  }

  //Handles characters that are not recognized by Bluetooth names
  String _setBleName(String name) {
    try {
      if (name.codeUnits.contains(0)) {
        return String.fromCharCodes(Uint8List.fromList(
            name.codeUnits.sublist(0, name.codeUnits.indexOf(0))));
      } else {
        return name;
      }
    } catch (_) {}
    return '--';
  }


  //ECG waveform data
  void _ecgWave(List<num> array) {
    if (kDebugMode) print('ECG = $array');
  }

  //Oxygen saturation waveform data
  void _spo2Wave(List<num> array) {
    if (kDebugMode) print('SpO₂ = $array');
  }

  //Heart rate and respiration rate
  void _hrResp(List<num> array) {
    if (array.isNotEmpty) {
      var status = array.first.toInt() & 0x02;
      //When it comes to compatibility between the two versions
      var hr = 0; //ECG
      var resp = 0; //RESP
      switch (array.length) {
        case 5:
          hr = status != 0 ? 0 : array[1].toInt();
          resp = status != 0 ? 0 : array[2].toInt();
          break;
        case 6:
          hr = status != 0 ? 0 : ((array[5].toInt() << 8) + array[1].toInt());
          resp = status != 0 ? 0 : array[2].toInt();
          break;
      }
      this.hr = hr;
      this.resp = resp;
    }
  }

  //Respiration rate waveform data
  void _respWave(List<num> array) {
    if (kDebugMode) print('RESP = $array');
  }

  //Blood Gate
  void _nibp(List<num> array) {
    if (array.isNotEmpty) {
      var state = (array[0].toInt() & (32 | 16 | 8 | 4)) >> 2;
      var sys = 0;
      var dia = 0;
      var map = 0.0;
      if (state == 0 || state == 7) {
        sys = array[2].toInt();
        map = array[3].toDouble();
        dia = array[4].toInt();
      }
      this.sys = sys;
      this.dia = dia;
      this.map = map;
    }
  }

  //Blood oxygen and pulse rate
  void _spo2Pr(List<num> array) {
    if (array.isNotEmpty) {
      var pr = 0;
      switch (array.length) {
        case 3:
          pr = array[2].toInt() == 255 ? 0 : array[2].toInt();
          break;
        case 4:
          pr = array[2].toInt() | (array[3].toInt() << 8);
          if (pr == 0xFF00) pr = 0;
          break;
        default:
          pr = 0;
          break;
      }
      spo2 = array[0].toInt() == 0 ? array[1].toInt() : 0;
      this.pr = pr;
    }
  }

  //Temperature
  void _temp(List<num> array) {
    if (array.isNotEmpty) {
      var status = array[0].toDou1;
      var value = array[1].toDou1 + array[2].toDou1 * 0.1;
      if (value < 0) value = 0;
      if (status == 64) {
        bodyTemp = true;
        temp = value;
        Future.delayed(const Duration(seconds: 6), () => bodyTemp = false);
      } else if (status != 0 && status != 2 && !bodyTemp) {
        temp = 0.0;
      } else {
        if (!bodyTemp) temp = value;
      }
    }
  }

  //Battery level
  void _battery(List<num> array) {
    if (array.isNotEmpty) {
      if (array.length >= 2) {
        battery = array[1].toInt();
      } else {
        battery = array[0].toInt();
      }
    }
  }

  //ECG peak
  void _ecgPeak(List<num> array) {
    //When lead data is available, ECG peaks are used
    if (kDebugMode) print('ECG peak = $array');
  }

  //Peak oxygen saturation
  void _spo2Peak(List<num> array) {
    if (kDebugMode) print('SpO₂ peak = $array');
  }

  //Notification refresh
  void refresh() => notifyListeners();
}

extension Format on num {
  String get intVal => this > 0 ? '$this' : '--';
  String get asFixed => this > 0 ? toStringAsFixed(1) : '--';
  double get toDou1 => this > 0 ? double.parse(toStringAsFixed(1)) :  0.0;
  String get batt => this > 0 ? '$this%' : '--';
}
