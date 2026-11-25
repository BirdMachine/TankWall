#!/usr/bin/env python3
"""Native smoke test on a disposable Android emulator, never a personal phone."""
import argparse,json,re,shlex,subprocess,time,xml.etree.ElementTree as ET
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('apk',type=Path)
parser.add_argument('--output',type=Path,default=Path('native-results'))
args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
PACKAGE='com.birdmachine.tamotank.livingbeta'
SERVICE=PACKAGE+'/org.godotengine.plugin.android.LiveWallpaper.LiveWallpaperService'
def adb(*argv,timeout=60,binary=False,check=True,input=None):
 r=subprocess.run(['adb',*argv],capture_output=True,text=not binary,timeout=timeout,input=input)
 if check and r.returncode:raise RuntimeError(str(argv)+': '+str(r.stderr))
 return r.stdout
def logs():return adb('logcat','-d','-v','brief','-s','godot:I','godotwp:V','AndroidRuntime:E')
def wait_for(test,label,seconds=90):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  if test():print('PASS:',label,flush=True);return
  time.sleep(2)
 raise RuntimeError('Timed out: '+label)
def screenshot(name):
 (args.output/(name+'.png')).write_bytes(adb('exec-out','screencap','-p',binary=True))
def ui():
 adb('shell','uiautomator','dump','/sdcard/tamotank-native-ui.xml')
 raw=adb('shell','cat','/sdcard/tamotank-native-ui.xml')
 return ET.fromstring(raw)
def tap_labels(labels):
 for node in ui().iter('node'):
  a=node.attrib;text=a.get('text','').strip().casefold()
  if a.get('enabled')!='true':continue
  matches=text in labels or any(label in a.get('resource-id','').casefold() for label in labels if '_' in label)
  if not matches:continue
  numbers=list(map(int,re.findall(r'\d+',a.get('bounds',''))))
  if len(numbers)==4:
   x1,y1,x2,y2=numbers
   if x2>x1 and y2>y1:
    adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2));return True
 return False
def active():
 value=adb('shell','dumpsys','wallpaper')
 (args.output/'wallpaper-state.txt').write_text(value)
 return any('mWallpaperComponent=' in line and PACKAGE in line for line in value.splitlines())
def read_care(path):return json.loads(adb('shell','run-as',PACKAGE,'cat',path))
try:
 adb('logcat','-c')
 adb('install','-r',str(args.apk),timeout=180)
 adb('shell','settings','put','global','window_animation_scale','0')
 adb('shell','settings','put','global','transition_animation_scale','0')
 adb('shell','settings','put','global','animator_duration_scale','0')
 adb('shell','am','start','-n',PACKAGE+'/com.godot.game.GodotApp')
 wait_for(lambda:'TamoTank: companion ready' in logs(),'foreground companion starts')
 tap_labels({'got it'})
 screenshot('companion')
 adb('shell','am','start','-a','android.service.wallpaper.CHANGE_LIVE_WALLPAPER','--ecn','android.service.wallpaper.extra.LIVE_WALLPAPER_COMPONENT',SERVICE)
 wait_for(lambda:'TamoTank: wallpaper ready' in logs(),'preview uses wallpaper mode')
 wait_for(lambda:'TamoTank: wallpaper frame drawn' in logs(),'wallpaper produces a frame')
 screenshot('wallpaper-preview')
 wait_for(lambda:tap_labels({'set wallpaper','set_wallpaper','apply_button'}),'Android set-wallpaper control',30)
 time.sleep(2)
 if not active():tap_labels({'home screen','home screen and lock screen','home and lock screens'})
 wait_for(active,'service is the applied wallpaper',40)
 adb('shell','input','keyevent','KEYCODE_HOME');time.sleep(3)
 screenshot('wallpaper-home')
 files=adb('shell','run-as',PACKAGE,'find','files','-name','companion.json').splitlines()
 assert len(files)==1, 'Expected one care save'
 path=files[0].strip();assert re.fullmatch(r'files/[A-Za-z0-9_./-]+',path)
 fixture=read_care(path);fixture.update(bond=17,snacks=4,pet_name='Pebble',backwall='21435bff')
 remote='cat > '+shlex.quote(path+'.test')+' && mv '+shlex.quote(path+'.test')+' '+shlex.quote(path)
 adb('shell','run-as '+shlex.quote(PACKAGE)+' sh -c '+shlex.quote(remote),input=json.dumps(fixture))
 wait_for(lambda:'TamoTank: wallpaper preferences refreshed' in logs(),'wallpaper reads foreground preferences')
 # Cross the foreground save interval; a stale wallpaper writer would now
 # overwrite the injected progress. This is a disposable test companion.
 time.sleep(35)
 current=read_care(path)
 assert (current['bond'],current['snacks'],current['pet_name'])==(17,4,'Pebble'), 'Wallpaper overwrote care progress'
 print('PASS: wallpaper does not overwrite shared care',flush=True)
 adb('shell','input','keyevent','KEYCODE_SLEEP');time.sleep(3)
 wait_for(lambda:'TamoTank wallpaper visible=false' in logs(),'hidden wallpaper pauses',30)
 visible_before=logs().count('TamoTank wallpaper visible=true')
 adb('shell','input','keyevent','KEYCODE_WAKEUP');adb('shell','wm','dismiss-keyguard');adb('shell','input','keyevent','KEYCODE_HOME')
 wait_for(active,'wallpaper survives wake')
 wait_for(lambda:logs().count('TamoTank wallpaper visible=true')>visible_before,'wallpaper simulation resumes after wake',30)
 time.sleep(3);screenshot('wallpaper-resumed')
 output=logs()
 assert 'FATAL EXCEPTION' not in output and 'Shader compilation failed' not in output and 'Program linking failed' not in output, 'Native crash or shader failure'
 (args.output/'result.json').write_text(json.dumps({'passed':True,'android':'34','checks':['foreground','preview','frame','apply','read-only care','settings refresh','visibility','wake']},indent=2))
finally:
 (args.output/'logcat.txt').write_text(logs())
