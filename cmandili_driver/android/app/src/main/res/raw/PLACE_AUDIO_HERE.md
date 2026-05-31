# Audio file required

Place your custom sound file in this directory:

  android/app/src/main/res/raw/driver_alarm.mp3

Rules:
- File name must be lowercase with no spaces.
- Recommended format: .mp3 or .ogg.
- The AudioAttributesUsage.alarm attribute makes Android repeat it via
  FLAG_INSISTENT even in DND / silent mode — keep the clip short (2-5 s).
- Suggested sound: loud ringtone, siren, or repeated beep.

Free sources: freesound.org, zapsplat.com (search "alarm ringtone").
