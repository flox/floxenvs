#!/usr/bin/env bash

script="[(importlib := __import__('importlib')), (warnings := importlib.import_module('warnings')), warnings.filterwarnings('ignore'), (torch := importlib.import_module('torch')), print('CUDA is available 🔥') if torch.cuda.is_available() else print('Metal is available 🍏') if torch.backends.mps.is_available() else print('I only see a CPU 😞')]"

python3 -c "$script"

