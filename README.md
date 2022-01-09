# Hack & Roll 2022

https://devpost.com/software/pal-streamer-v2

## Inspiration

The idea was inspired by my old project I did back in May 2020, PAL-Streamer. It got featured on the [front page of Hackaday.com](https://hackaday.com/2020/08/26/driving-a-pal-tv-over-rf-thanks-to-pwm-harmonics/). However with a microcontroller, precise timing was a major issue. Most recently I have been learning about FPGAs and how to program them using the Verilog language. Therefore, for this competition, I realised that FPGAs will be the perfect tool to tackle the limitations of PAL-Streamer V1.

## What it does

**Theory in-short**

In Singapore, the PAL standard was used for analog broadcast. The video signal uses amplitude modulation (AM). To emulate the amplitude, the duty cycle of a digital PWM signal is varied. The modulation frequency is usually very high, so a trick used is to make use of the fact that PWM is a square wave to transmit a modulated signal at a low frequency. Since square waves have odd harmonics, and there will be high frequency components (every odd multiple). With this, the target frequency of the TV channel is easily attained.

**Main outcome of this project**

The FPGA is configured to count the number of ticks and output the correct signal for that point of time (similar to a lookup table which runs in parallel). It waits for hex-encoded data over serial UART from the PC and stores it into the RAM. At the same time, the video signal is being generated based on the contents of the RAM. As all these are "running" in parallel, thus the video feed is extremely stable. In real TV modulators, this is achieved with multiple complex circuits, but in this project it is achieved with one off-the-shelf board.

## Hardware build

FPGA hardware 
- Lichee Tang Nano 4K (a cheap chinese dev board for about SGD15)
- Programmed using Gowin IDE

Serial communication
- FT232R USB-to-UART converter (about SGD 10)
- Python program to convert image data into serial data

Some optional resistors to prevent damage in case I misconnect something.

## Challenges we ran into

Cannot solve within the hackathon...

**Slow transfer rate**:
As I had also implemented a higher resolution for PAL-Streamer V2, the transfer rate has become noticeably slow due to the larger buffer. The bottleneck is the Serial-to-USB converter. Ideally should find a high speed device to directly talk over USB.

**Antenna issues**:

(or rather, lack of antenna) Some unknown interference at random times?

## Accomplishments

Finally a stable video feed

- The excitement when the outcome matches theory and finally knowing the correct tool for the correct job

## What we learned

**FPGA timing constraints**
- For example, bit-lookups are slow (produces glitches), so better to use bit shifting.

## What's next for PAL Streamer V2

Learn how to do faster transfer of the images. Then I can perhaps stream a video over in real-time to watch old-school Netflix.

## Slides

[See presentation slides here](https://docs.google.com/presentation/d/e/2PACX-1vRSzwqjrhXqoWzWzUBBPPLAm2e5uzouz0kRG_VlQ00lmlds59ZXYvTVfIH_06Vyf_YL1KSzIfbgbqsu/pub?start=false&loop=false&delayms=3000)

<iframe src="https://docs.google.com/presentation/d/e/2PACX-1vRSzwqjrhXqoWzWzUBBPPLAm2e5uzouz0kRG_VlQ00lmlds59ZXYvTVfIH_06Vyf_YL1KSzIfbgbqsu/embed?start=false&loop=false&delayms=3000" frameborder="0" width="960" height="569" allowfullscreen="true" mozallowfullscreen="true" webkitallowfullscreen="true"></iframe>

## Acknowledgements

Verilog Code
- FPGA Hello world Template code: https://github.com/sipeed/TangNano-4K-example/tree/main/led_test
- UART module: https://www.nandland.com/vhdl/modules/module-uart-serial-port-rs232.html
- BRAM module: https://github.com/Megamemnon/bram
- PLL clock: https://www.bananatronics.org/first-steps-with-the-tang-nano-fpga-development-board/ 
- Some snippets from my old projects: https://github.com/zst123/Vidor-Music-Jukebox 

Python Code
- PAL-Streamer V1: https://github.com/zst123/PAL-Streamer/blob/master/PC%20Software/usart_new.py
