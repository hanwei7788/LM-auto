LM Audio Test Tool
==================

Requirements:
FFMPEG:
 - Command line tool needed for audio recording.

Octave:
 - octave-cli "GNU Octave language for numerical computations"
     * command line tool needed for running the analyzers
 - octave-ltfat "Large Time/Frequency Analysis Toolbox"
 - octave-signal "signal processing functions for Octave"


Contents:

 - analyzers/
    octave files run for audio quality analysis
    thdn.m
      Calculator for Total Harmonic Distortion + Noise
      Calculates dominant frequency, and the amount of THD+N compared to full signal
      Prints mean values and separately on each channel

 - ruby/
    Ruby interface for automated functional testing

 - testfiles/
    Audio files for use with analyzer

 - examples/
    Example test scripts for automated functional testing

Installation:
 - Build and install ruby gem for use with automated testing rig
   $ cd ruby
   $ rake gem
   $ sudo gem install pkg/audio_test_tool-0.0.1.gem

