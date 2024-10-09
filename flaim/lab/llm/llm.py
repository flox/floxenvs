#!/usr/bin/env python

import sys
import warnings
from ctransformers import AutoModelForCausalLM
from transformers import logging

warnings.filterwarnings("ignore")
logging.set_verbosity(50)
logging.disable_progress_bar()

prompt = sys.argv[1] if len(sys.argv) > 1 else "Flox rocks because"
print(prompt + "...")

model = AutoModelForCausalLM.from_pretrained("TheBloke/Llama-2-7b-Chat-GGUF")

for text in model(prompt, stream=True):
    print(text, end="", flush=True)
