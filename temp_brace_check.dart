import 'dart:io';

void main() {
  final text = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  int line = 1;
  final stack = <String>[];
  bool inSingle = false;
  bool inDouble = false;
  bool inTripleSingle = false;
  bool inTripleDouble = false;
  bool escape = false;
  for (int i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch == '\n') line++;
    if (inSingle) {
      if (escape) {
        escape = false;
      } else if (ch == '\\') {
        escape = true;
      } else if (ch == "'") {
        inSingle = false;
      }
      continue;
    }
    if (inDouble) {
      if (escape) {
        escape = false;
      } else if (ch == '\\') {
        escape = true;
      } else if (ch == '"') {
        inDouble = false;
      }
      continue;
    }
    if (inTripleSingle) {
      if (ch == "'" && i + 1 < text.length && text[i + 1] == "'") {
        inTripleSingle = false;
      }
      continue;
    }
    if (inTripleDouble) {
      if (ch == '"' && i + 1 < text.length && text[i + 1] == '"') {
        inTripleDouble = false;
      }
      continue;
    }
    if (ch == '/' && i + 1 < text.length && text[i + 1] == '/') {
      while (i < text.length && text[i] != '\n') {
        i++;
      }
      if (i < text.length) line++;
      continue;
    }
    if (ch == '/' && i + 1 < text.length && text[i + 1] == '*') {
      i += 2;
      while (i < text.length - 1 && !(text[i] == '*' && text[i + 1] == '/')) {
        if (text[i] == '\n') line++;
        i++;
      }
      continue;
    }
    if (ch == "'") { inSingle = true; continue; }
    if (ch == '"') { inDouble = true; continue; }
    if (ch == '(' || ch == '{' || ch == '[') { stack.add('$ch:$line'); }
    else if (ch == ')' || ch == '}' || ch == ']') {
      if (stack.isEmpty) {
        print('extra $ch at line $line');
        return;
      }
      final open = stack.removeLast();
      final expected = {
        ')': '(',
        ']': '[',
        '}': '{',
      }[ch]!;
      if (!open.startsWith(expected)) {
        print('mismatch $open -> $ch at line $line');
        return;
      }
    }
  }
  if (stack.isNotEmpty) {
    print('remaining ${stack.join(',')}');
  } else {
    print('balanced');
  }
}
