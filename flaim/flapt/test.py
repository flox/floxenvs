#!/usr/bin/env python

import warnings
warnings.filterwarnings("ignore")

import torch

if torch.cuda.is_available():
  print("CUDA is available 🔥")
elif torch.backends.mps.is_available():
  print("Metal is available 🍏")
else:
  print("I only see a CPU 😞")

