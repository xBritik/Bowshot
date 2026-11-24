"""Offer the resolution control only when the rewritten build supports it, and the game's upscaler choice only to games whose shader map holds their own upscaler (an NDSR pack's network: game.py upscaler_keys)."""
from pathlib import Path
import sys,tempfile,unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'games'))
import settings

class FrameRateOption(unittest.TestCase):
    def test_40_only_where_the_frame_step_takes_ticks_of_1_120_s(self):
        """40 fps needs a frame step stub in ticks of 1/120 s (FRAME_STEP_120 in main's fixups table: Ocarina of Time's ratio stub); both platforms offer it, the host and iOS launcher check the screen"""
        with tempfile.TemporaryDirectory() as tmp,patch.object(settings.nacp,'languages',return_value=['en-US']):
            p=Path(tmp)/'main.fixups.tsv'
            for header,platform,has in [('# FRAME_STEP_120\t1\n','ios',True),('# FRAME_STEP_120\t1\n','mac',True),('','ios',False),('# DYNAMIC_RESOLUTION\t1\n','mac',False)]:
                p.write_text(header)
                with patch.dict(settings.os.environ,{'SETTINGS_PLATFORM':platform}):
                    fps=next(s for s in settings.build('0400486024DEC000',tmp,'unused')['settings'] if s['env']=='DM_FPS_TARGET')
                self.assertEqual(fps['default'],'60',(header,platform))
                self.assertEqual(fps['options'],[['30','30 fps']]+([['40','40 fps']] if has else [])+[['60','60 fps']],(header,platform))

class UpscalerSetting(unittest.TestCase):
    def test_a_profile_may_default_to_metalfx(self):   # Bowshot: Ocarina of Time's upscaler_default metalfx
        with tempfile.TemporaryDirectory() as tmp,patch.object(settings.nacp,'languages',return_value=['en-US']):
            (Path(tmp)/'main.fixups.tsv').write_text('')
            up=[s for s in settings.build('0400486024DEC000',tmp,'unused')['settings'] if s['env']=='DM_UPSCALER']
            self.assertEqual(up[0]['default'],'metalfx')

if __name__=='__main__':unittest.main()
