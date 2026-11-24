"""The launcher's settings (dm/games/settings.tsv through dm/games/settings.py): rows by graphics API and profile, single-screen sections, toggle values and the strict format;
the meta column's optional fields, and the written list against docs/launcher.schema.json, the contract front ends read."""
import importlib.util
import json
import os
import re
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('launcher_settings', ROOT / 'dm/games/settings.py')
settings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(settings)

BOTW, WONDER = '01007EF00011E000', '010015100B514000'
PERFORMANCE_NVN = ['DM_PRESENT_SNAP', 'DM_PSO_MTL4', 'DM_PSO_PREBUILD', 'DM_NVN_ENC_THREAD', 'DM_NVN_TEX_MIP_SKIP', 'DM_FPS_HOLD', 'DM_METAL_HUD']


def build(gid, api, platform=None):
    env = {'GFXAPI': api, **({'SETTINGS_PLATFORM': platform} if platform else {})}
    with tempfile.TemporaryDirectory() as tmp, patch.object(settings.nacp, 'languages', return_value=['en-US']), patch.dict(os.environ, env):
        if not platform: os.environ.pop('SETTINGS_PLATFORM', None)
        return {s['env']: s for s in settings.build(gid, tmp, Path(tmp) / 'control.nacp')['settings']}


def rows_with_languages(listed):   # the settings rows, by variable, of a game whose control data lists these languages
    with tempfile.TemporaryDirectory() as tmp, patch.object(settings.nacp, 'languages', return_value=listed), patch.dict(os.environ, {'GFXAPI': 'nvn', 'DM_LANG': 'en-US'}):
        return {s['env']: s for s in settings.build(BOTW, tmp, Path(tmp) / 'control.nacp')['settings']}


class LauncherSettingsTests(unittest.TestCase):
    def test_unknown_platform_is_rejected(self):
        with self.assertRaisesRegex(SystemExit, 'SETTINGS_PLATFORM must be ios or mac'):
            build(WONDER, 'nvn', 'mca')

    def test_meta_is_strict(self):
        self.assertEqual(settings.meta('level=basic; needs=DM_RUMBLE=1', 1), {'level': 'basic', 'needs': 'DM_RUMBLE=1'})
        self.assertEqual(settings.meta('', 1), {})
        for bad, why in [('colour=red', 'unknown meta key'), ('level', 'unknown meta key'), ('level=basic;level=basic', 'twice'),
                         ('level=advanced', 'does not match'), ('needs=DM_RUMBLE', 'does not match'), ('needs=rumble=1', 'does not match')]:
            with self.subTest(bad=bad), self.assertRaises(SystemExit) as e:
                settings.meta(bad, 1)
            self.assertIn(why, str(e.exception))

    def test_meta_keys_agree_with_the_docs_and_the_schema(self):
        """A key is added in settings.py's META, docs/frontends.md and docs/launcher.schema.json together"""
        schema = json.loads((ROOT / 'docs/launcher.schema.json').read_text(encoding='utf-8'))
        fields = schema['$defs']['setting']['properties']
        docs = (ROOT / 'docs/frontends.md').read_text(encoding='utf-8')
        for key in settings.META:
            with self.subTest(key=key):
                self.assertIn(key, fields)
                self.assertNotIn(key, schema['$defs']['setting']['required'], 'a meta field is optional')
                self.assertRegex(docs, rf'- `{key}` \(optional\)')
        self.assertEqual(schema['properties']['schema']['const'], settings.SCHEMA)

    def test_schema_1_takes_new_sections_but_not_new_kinds(self):
        """A section is a heading a reader draws by its name, so a new one stays schema 1; a new kind would not"""
        schema = json.loads((ROOT / 'docs/launcher.schema.json').read_text(encoding='utf-8'))
        row = {'env': 'DM_X', 'kind': 'toggle', 'section': 'Picture', 'label': 'X', 'note': '', 'default': '1', 'on': '1', 'off': '0'}
        self.assertEqual(conforms({'schema': 1, 'game': BOTW, 'settings': [row]}, schema, schema), [])
        self.assertNotEqual(conforms({'schema': 1, 'game': BOTW, 'settings': [{**row, 'kind': 'slider'}]}, schema, schema), [])

    def test_ocarina_render_scale_has_named_steps(self):   # Bowshot: the slider in eighteenths of the game's own size with its marks, on Potato by default (no Resolution presets)
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / 'main.fixups.tsv').write_text('# RENDER_SCALE\t1\n')
            rows = {s['env']: s for s in settings.build('0400486024DEC000', tmp, Path(tmp) / 'control.nacp')['settings']}
        self.assertNotIn('DM_RES_PRESET', rows)
        rs = rows['DM_RENDER_SCALE']
        self.assertEqual((rs['min'], rs['max'], rs['default'], 'needs' in rs), (0.6666667, 1.0, '0.6666667', False))
        self.assertEqual(rs['base'], {'docked': [1920, 1080], 'handheld': [1440, 810]})
        marks = {round(float(v), 4): name for v, name in rs['marks']}
        self.assertEqual(marks, {0.6667: 'Potato', 1.0: "Game's own"})
        for k, name in ((0, 'Potato'), (6, "Game's own")):   # each mark is a step of the slider, and a whole 16:9 size of the handheld 1440x810
            v = rs['min'] + k * rs['step']
            self.assertEqual(marks[round(v, 4)], name)
            self.assertEqual((round(1440 * float(f'{v:.4f}')), round(810 * float(f'{v:.4f}'))), {0: (960, 540), 6: (1440, 810)}[k])

def conforms(value, node, root, at='$'):
    """The JSON Schema keywords launcher.schema.json uses (type, required, properties, items, enum, const, pattern, $ref, allOf with
    if / then), as a list of problems: enough to hold the written lists to the contract without a jsonschema package"""
    if '$ref' in node: return conforms(value, root['$defs'][node['$ref'].rsplit('/', 1)[1]], root, at)
    problems = []
    kinds = {'object': dict, 'array': list, 'string': str, 'integer': int, 'number': (int, float)}
    if 'type' in node and not isinstance(value, kinds[node['type']]): return [f'{at}: not a {node["type"]}']
    if 'const' in node and value != node['const']: problems.append(f'{at}: not {node["const"]!r}')
    if 'enum' in node and value not in node['enum']: problems.append(f'{at}: not one of {node["enum"]}')
    if 'pattern' in node and not re.search(node['pattern'], value): problems.append(f'{at}: does not match {node["pattern"]}')
    if isinstance(value, dict):
        problems += [f'{at}: no {k}' for k in node.get('required', []) if k not in value]
        for k, v in value.items():
            if k in node.get('properties', {}): problems += conforms(v, node['properties'][k], root, f'{at}.{k}')
        for rule in node.get('allOf', []):
            if not conforms(value, rule['if'], root, at): problems += conforms(value, rule['then'], root, at)
    if isinstance(value, list) and 'items' in node:
        for i, v in enumerate(value): problems += conforms(v, node['items'], root, f'{at}[{i}]')
    return problems


if __name__ == '__main__':
    unittest.main()
