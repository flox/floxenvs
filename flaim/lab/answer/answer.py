#!/usr/bin/env python

import warnings
warnings.filterwarnings("ignore")

import sys
import torch
from imgcat import imgcat
from transformers import T5Tokenizer, T5ForConditionalGeneration
from transformers import logging

logging.set_verbosity(50)
logging.disable_progress_bar()

tokenizer = T5Tokenizer.from_pretrained("google/flan-t5-base")
model = T5ForConditionalGeneration.from_pretrained("google/flan-t5-base", device_map="auto", torch_dtype=torch.float16)

prompt = sys.argv[1] if len(sys.argv) > 1 else "a fox in a henhouse"

if torch.cuda.is_available():
  input_ids = tokenizer(prompt, return_tensors="pt").input_ids.to("cuda")
elif torch.backends.mps.is_available():
  input_ids = tokenizer(prompt, return_tensors="pt").input_ids.to("mps")
else:
  input_ids = tokenizer(prompt, return_tensors="pt").input_ids

outputs = model.generate(input_ids)
print(tokenizer.decode(outputs[0], skip_special_tokens=True))
