# Yumyoo Toolkit

A collection of custom REAPER Lua scripts and JSFX built to streamline modern beatmaking, MIDI sequencing, and sampling workflows. 

## Included Tools

* **FL Studio-Style Auto Glide & Toggle:** A defer script and companion toggle action that brings native FL Studio-style overlapping note glide behavior directly into REAPER's MIDI editor. It automatically calculates and applies precise pitch bend messages between overlapping notes, optimized for 808s and synth leads.
* **Master Key Transposer:** A project-wide utility that allows you to globally manage, transpose, and shift the root musical key of your project across multiple MIDI items and tracks simultaneously.
* **MIDI Phase Plugin & Toggle:** A JSFX and companion toggle script designed to flip the polarity/phase of a track directly at the instrument generation stage, allowing for quick phase alignment of layered synths or basses without needing to bounce MIDI to audio first.
* **RS5k Root Note Finder:** A workflow enhancement for ReaSamplomatic5000 that automatically detects and assigns the correct root MIDI note for loaded samples, eliminating the need to manually pitch-match and tune imported one-shots.

## Installation via ReaPack

1. Copy this repository URL: `https://github.com/Yumyoo/Yumyoo-Toolkit/raw/master/index.xml`
2. In REAPER, navigate to **Extensions** > **ReaPack** > **Import repositories**.
3. Paste the URL and click **OK**.
4. Navigate to **Extensions** > **ReaPack** > **Browse packages**, search for "Yumyoo", right-click the scripts you want, select **Install**, and click **Apply** in the bottom right.
