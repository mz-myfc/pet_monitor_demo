import '../helper.dart';

class DataParse {
  static final DataParse instance = DataParse();

  List<int> _buffArray = [];

  void init() {
    _buffArray = [];
  }

  void parse(List<int> array) {
    _buffArray += array;
    var i = 0; //Current index
    var validIndex = 0; //Valid indexes
    var maxIndex = _buffArray.length - 7; //Leave at least enough room for a minimum set of data
    while (i <= maxIndex) {
      //Failed to match the headers
      if (_buffArray[i] != 0x55 || _buffArray[i + 1] != 0xAA) {
        i += 1;
        validIndex = i;
        continue;
      }
      var length = _buffArray[i + 2]; //The data header is successfully matched
      var type = _buffArray[i + 3]; //Packet type
      var dataCount = length - 3; //The amount of valid data
      var packageLength = length + 2; //Package length

      //If no valid data is obtained, skip 2 to avoid missing valid data
      if (dataCount <= 0) {
        i += 2;
        validIndex = i;
        continue;
      }
      //If the remaining data length is less than the data length of the current group, you do not need to process it in this cycle
      if (i + packageLength > _buffArray.length) {
        validIndex = i;
        break;
      }
      var checkSum = _buffArray[i + 4 + dataCount] & 0xFF; //The packet check digit, which is taken after 8 digits
      var sum = 0;
      List<num> array = [];
      for (int index = 0; index < dataCount; index++) {
        var value = _buffArray[i + 4 + index];
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
      Helper.h.readData(type, array);

      i += packageLength; //Get valid data, skip one set of data, and detect the next set of data
      validIndex = i;
      continue;
    }
    //The array before the valid index belongs to the scanned and is not needed, and it is directly emptied
    _buffArray = _buffArray.sublist(validIndex); //Reorganize the cache array, delete all the data before the valid index
  }
}