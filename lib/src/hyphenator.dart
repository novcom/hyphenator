import 'extensions.dart';
import 'hyphenator_resource_loader.dart';
import 'pattern.dart';

const _startEndMarker = '.';
const _exceptionDelimiter = '-';

// RegExp('\\w') works only for English letters
List<int> _createExceptionMask(String exc) {
  final list = <int>[];

  int index = 0;

  while (index < exc.length) {
    if (exc[index] == _exceptionDelimiter) {
      list.add(1);
      index++;
    } else {
      list.add(0);
    }

    index++;
  }

  list.add(0);

  return list;
}

class Hyphenator {
  Hyphenator({
    required ResourceLoader resource,
    this.hyphenateSymbol = '\u{00AD}',
    this.minWordLength = 5,
    this.minLetterCount = 3,
  })  : assert(minWordLength > 0),
        _patterns = resource.patternsStrings
            .map(
              (pattern) => Pattern.from(pattern),
            )
            .toList()
              ..sort() {
    _exceptions.addEntries(
      resource.exceptionsStrings.map(
        (exception) => MapEntry(
          exception.replaceAll(_exceptionDelimiter, ''),
          _createExceptionMask(exception),
        ),
      ),
    );
  }

  final List<Pattern> _patterns;
  final Map<String, List<int>> _exceptions = {};
  final String hyphenateSymbol;
  final int minWordLength;
  final int minLetterCount;

  String hyphenate(String text) {
    var currentWord = StringBuffer();
    var result = new StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final c = text[i];

      if (c.isLetter) {
        currentWord.write(c);
      } else {
        if (currentWord.length > 0) {
          result.write(hyphenateWord(currentWord.toString()));
          currentWord.clear();
        }
        result.write(c);
      }
    }

    result.write(hyphenateWord(currentWord.toString()));

    return result.toString();
  }

  String hyphenateWord(String inputWord) {
    if (_isNotNeedHyphenate(inputWord)) return inputWord;

    final word = inputWord.toLowerCase();

    List<int>? hyphenationMask;

    if (_exceptions.containsKey(word))
      hyphenationMask = _exceptions[word];
    else {
      final levels = _generateLevelsForWord(word);
      hyphenationMask = _hyphenatedMaskFromLevels(levels);
      _correctHyphenationMask(hyphenationMask);
    }

    return _hyphenateByMask(inputWord, hyphenationMask);
  }

  List<String> hyphenateWordToList(String inputWord) {
    if (_isNotNeedHyphenate(inputWord)) return <String>[inputWord];

    final word = inputWord.toLowerCase();

    List<int>? hyphenationMask;

    if (_exceptions.containsKey(word))
      hyphenationMask = _exceptions[word];
    else {
      final levels = _generateLevelsForWord(word);
      hyphenationMask = _hyphenatedMaskFromLevels(levels);
      _correctHyphenationMask(hyphenationMask);
    }

    return _hyphenateByMaskToList(inputWord, hyphenationMask);
  }

  Map<String, List<int>> _patternCache = {};

  List<int> _generateLevelsForWord(String word) {
  final wordString = '$_startEndMarker$word$_startEndMarker';
  final levels = List.filled(wordString.length, 0);

  for (int i = 0; i < wordString.length - 2; ++i) {
    for (int count = 1; count <= wordString.length - i; ++count) {
      var patternFromWord = wordString.substring(i, i + count);

      // Check cache first
      if (_patternCache.containsKey(patternFromWord)) {
        _updateLevelsFromCache(levels, _patternCache[patternFromWord]!, i);
        continue;
      }

      var pattern = Pattern(patternFromWord);

      // Use binary search for pattern matching
      int patternIndex = _binarySearchPattern(pattern);

      if (patternIndex == -1) break;

      if (pattern.compareTo(_patterns[patternIndex]) >= 0) {
        List<int> patternLevels = [];
        for (int levelIndex = 0;
            levelIndex < _patterns[patternIndex].levelsCount - 1;
            ++levelIndex) {
          int level = _patterns[patternIndex].levelByIndex(levelIndex)!;
          patternLevels.add(level);
          if (level > levels[i + levelIndex]) levels[i + levelIndex] = level;
        }
        // Cache the pattern levels
        _patternCache[patternFromWord] = patternLevels;
      }
    }
  }
  return levels;
  }

  int _binarySearchPattern(Pattern pattern) {
  int low = 0;
  int high = _patterns.length - 1;

  while (low <= high) {
    int mid = (low + high) ~/ 2;
    int cmp = _patterns[mid].compareTo(pattern);

    if (cmp < 0) {
      low = mid + 1;
    } else if (cmp > 0) {
      high = mid - 1;
    } else {
      return mid;
    }
  }
  return low < _patterns.length ? low : -1;
  }

  void _updateLevelsFromCache(List<int> levels, List<int> cachedLevels, int startIndex) {
  for (int i = 0; i < cachedLevels.length; i++) {
    if (cachedLevels[i] > levels[startIndex + i]) {
      levels[startIndex + i] = cachedLevels[i];
    }
  }
  }

  List<int> _hyphenatedMaskFromLevels(List<int> levels) {
  int length = levels.length - 2;
  final hyphenationMask = List<int>.filled(length, 0);

  for (int i = 1; i < length; i++) {
    if (levels[i + 1] % 2 != 0) hyphenationMask[i] = 1;
  }

  return hyphenationMask;
  }

  void _correctHyphenationMask(List<int> mask) {
  if (mask.length > minLetterCount) {
    for (int i = 0; i < minLetterCount; i++) {
      mask[i] = 0;
    }
  }
  }

  String _hyphenateByMask(String word, List<int>? mask) {
    var result = StringBuffer();
    for (int i = 0; i < word.length; i++) {
      if (mask![i] > 0) result.write(hyphenateSymbol);
      result.write(word[i]);
    }
    return result.toString();
  }

  List<String> _hyphenateByMaskToList(String word, List<int>? mask) {
    StringBuffer currentSyllable = StringBuffer();
    List<String> returnList = <String>[];

    for (int i = 0; i < word.length; i++) {
      if (mask![i] > 0) {
        returnList.add(currentSyllable.toString());
        currentSyllable.clear();
      }
      currentSyllable.write(word[i]);
    }

    returnList.add(currentSyllable.toString());
    return returnList;
  }

  bool _isNotNeedHyphenate(String input) => input.length < minWordLength;
}

