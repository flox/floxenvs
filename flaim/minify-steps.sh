#!/bin/bash

# pip install Oneliner-Py

for x in flapt/test.py image/image.py; do
	instructions=$(python3 -m oneliner $x)
	echo $x
	echo $instructions
	echo 
done
