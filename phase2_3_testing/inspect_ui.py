import xml.etree.ElementTree as ET
import sys

sys.stdout.reconfigure(encoding='utf-8')
path = sys.argv[1] if len(sys.argv) > 1 else 'phase2_3_testing/device_audit/window_dump.xml'
tree = ET.parse(path)
root = tree.getroot()

for node in root.iter('node'):
    text = node.attrib.get('text', '').strip()
    desc = node.attrib.get('content-desc', '').strip()
    bounds = node.attrib.get('bounds', '')
    if text or desc:
        print(f"[{bounds}] Text='{text}' | Desc='{desc}'")
