#!/usr/bin/env python

import warnings
warnings.filterwarnings("ignore")

import sys
import torch
from diffusers import StableDiffusionPipeline
from diffusers import logging

def draw(image):
    import tempfile
    import subprocess
    import os
    with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as temp_file:
        output_file = temp_file.name
        image.save(output_file)

    subprocess.run(['viu', output_file], check=True)
    os.remove(output_file)

logging.set_verbosity(50)
logging.disable_progress_bar()

pipe = StableDiffusionPipeline.from_pretrained("IDKiro/sdxs-512-0.9", torch_dtype=torch.float32)

if torch.cuda.is_available():
  pipe.to("cuda")
elif torch.backends.mps.is_available():
  pipe.to("mps")

prompt = sys.argv[1] if len(sys.argv) > 1 else "a fox in a henhouse"

pipe.set_progress_bar_config(disable=True)

image = pipe(prompt=prompt, num_inference_steps=1, guidance_scale=0).images[0]
image.save(f"{prompt}.png")

draw(image)

