from pathlib import Path
p=Path(r"d:\GitHub\DeenMate_SDP2\lib\screens\calendar_tab.dart")
s=p.read_text(encoding='utf-8')
print('chars:', len(s))
print('{', s.count('{'), '}', s.count('}'))
print('(', s.count('('), ')', s.count(')'))
print('[', s.count('['), ']', s.count(']'))
