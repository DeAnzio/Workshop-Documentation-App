from pathlib import Path
import re

root = Path('lib')
count = 0
for path in root.rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    new = re.sub(r'\bSupabaseService\b', 'BackendService', text)
    if new != text:
        path.write_text(new, encoding='utf-8')
        print(path)
        count += 1
print(f'Replaced in {count} files')
