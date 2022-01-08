
#!/usr/bin/env python3
'''
Usage:

    python3 usart_new.py <COM_PORT> <IMAGE_FILE> <GIF_DELAY>

Example:
    python3 usart_new.py COM2 trollface.gif 0.01
    python3 usart_new.py COM2 image.png
'''
import serial
import time
import sys
from PIL import Image

def convert_pil_format(im1):
    # im1 = im.convert('L') # monochrome
    im1 = im.convert('1', dither=Image.NONE) # black and white
    im1 = im1.resize((x, y))
    # im1.show()
    return im1

import re

def convert_pil_to_hexarray(im):
    display = []
    imageSizeW, imageSizeH = im.size
    imagePixels = im.getdata()
    for j in range(0, imageSizeH):
        x_bytes = 0
        for i in range(0, imageSizeW):
            if imagePixels[j*imageSizeW + i] != 0: #if im.getpixel((i, j)) != 0:
                x_bytes |= (1 << i)

        x_chars = x_bytes.to_bytes(x // 8 + 1, byteorder = 'little')
        x_chars = x_chars.hex().upper()

        # swap every nibble
        x_chars = re.sub(r'(.)(.)', r'\2\1', x_chars)

        display.append(x_chars)
    return display


def realign_mcu(ser, xi, y):
    attempts = 0
    while ser.in_waiting == 0 and attempts < y*3:
        ser.write(b'\x00'*(xi-1) + b'\xFF'*(1))
        attempts += 1
    ser.reset_input_buffer()


def upload_to_mcu(display_array, x, y):
    buf = "#"
    for i, line in enumerate(display_array):
        if i < y:
            buf += line[:x]
            buf += "+"
    ser.write(buf.encode())
    ser.flush()


if __name__ == '__main__':
    ser = serial.Serial(
        port=sys.argv[1],
        baudrate=115200,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE)

    print(f"Starting {ser.port} at {ser.baudrate}")
    print("----")

    x = 300
    y = 512
    print(f"Image size: {x}x{y}")

    im = Image.open("image.png" if not len(sys.argv) >= 3 else sys.argv[2])

    if (not hasattr(im, 'is_animated')) or (not im.is_animated):
        # Static PNG or JPG
        im1 = convert_pil_format(im)
        display = convert_pil_to_hexarray(im1)
        #realign_mcu(ser, xi, y)
        upload_to_mcu(display, x, y)
        print("Sent all")
    else:
        # Animated GIF
        print(f"Animation frames: {im.n_frames}")

        frame_array = []
        for frame in range(0, im.n_frames):
            print(f"Process frames: {frame}")
            im.seek(frame)
            
            im1 = convert_pil_format(im)
            array = convert_pil_to_hexarray(im1)
            frame_array.append(array)

        #realign_mcu(ser, xi, y)

        fps = 0
        while True:
            try:
                time_start = time.time()
                for i, array in enumerate(frame_array):
                    upload_to_mcu(array, x, y)
                    time.sleep(0.01 if not len(sys.argv) >= 4 else float(sys.argv[3]))
                    print(f"Frame: {i}  |  FPS: {fps:.2f}")
                time_end = time.time()

                fps = len(frame_array) / (time_end - time_start)
                while ser.in_waiting > 0:
                    print(">>", ser.read())
            except KeyboardInterrupt:
                print("Halting.")
                quit()

quit()
