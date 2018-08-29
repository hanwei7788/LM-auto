#! /usr/bin/octave -qf

#*!
#* \file
#* \brief thdn.m foo
#*
#* Copyright of Link Motion Ltd. All rights reserved.
#*
#* Contact: info@link-motion.com
#*
#* \author Niko Vähäsarja <niko.vahasarja@nomovok.com>
#*
#* any other legal text to be defined later
#*

filename = argv(){1};

pkg load ltfat

# read waveform from file
[y, fs, nbits] = wavread(filename);

# set number of frequency bins fft divides the frequency range (0..fs) 
#   needs to be power of 2
#   (bigger is more accurate but needs more data as input)
nf = 1024*512;

# transform signal to frequency domain
Y = fft(y,nf);

# calculate power of each frequency, and find maximums per channel
Pyy = Y.*conj(Y)/nf;
[maxes, bin] = max(Pyy);

# calculate frequency from the bin number of channel maximums (dominant frequency of the signal)
f = fs/2*linspace(0,1,nf/2+1);
frqs = f(bin);

# create ranges around the maximum frequencies, and the mirrored counterpart
range1 = floor(bin.*0.9) : ceil(bin.*1.1);
# frequency is mirrored around DC components (real and complex)
range2 = nf+2-range1;

# calculate original signal rms power (from equal inverse fft to be certain these are comparable values)
totalpower = rms(ifft(Y));

# filter out the ranges around the peak frequency
Y(range1 ,:) = 0;
Y(range2 ,:) = 0;

# calculate filtered signal rms power (like totalpower before)
noisepower = rms(ifft(Y));

# total harmonic distortions + noise is calculated as ratio of filtered signal divided by full signal
thdn = noisepower./totalpower;

# output meaned values
printf("%d %d\n", mean(frqs), mean(thdn))

# output number of channels and channel based data
printf("%d\n", columns(frqs))
for i = (1:columns(frqs))
    printf("ch%d %d %d\n", i, frqs(i), thdn(i))
endfor
