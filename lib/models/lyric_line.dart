class LyricLine {
  final Duration time;
  final String text;

  LyricLine({required this.time, required this.text});

  factory LyricLine.fromLrc(String line) {
    final regex = RegExp(r'\[(\d+):(\d+\.\d+)\](.*)');
    final match = regex.firstMatch(line);
    if (match == null) {
      return LyricLine(time: Duration.zero, text: line);
    }

    final minutes = int.parse(match.group(1)!);
    final seconds = double.parse(match.group(2)!);
    final text = match.group(3)!.trim();

    return LyricLine(
      time: Duration(minutes: minutes, milliseconds: (seconds * 1000).round()),
      text: text,
    );
  }
}
