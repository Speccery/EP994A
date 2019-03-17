#!/bin/bash
# copy the binary files and hexdump them
cp tms99105-read.bin flag-testing/
cp softcpu-read.bin  flag-testing/
cd flag-testing
hexdump -C tms99105-read.bin > tms99105-read.txt
hexdump -C softcpu-read.bin > softcpu-read.txt
