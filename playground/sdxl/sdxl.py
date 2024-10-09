#!/usr/bin/env python

import warnings
warnings.filterwarnings("ignore")

import sys
import torch
from imgcat import imgcat
from diffusers import AutoPipelineForText2Image
from diffusers import logging

logging.set_verbosity(50)
logging.disable_progress_bar()

if torch.cuda.is_available():
  pipe = AutoPipelineForText2Image.from_pretrained("stabilityai/sd-turbo", torch_dtype=torch.float16, variant="fp16")
  pipe.to("cuda")
elif torch.backends.mps.is_available():
  pipe = AutoPipelineForText2Image.from_pretrained("stabilityai/sd-turbo")
  pipe.to("mps")
else:
  pipe = AutoPipelineForText2Image.from_pretrained("stabilityai/sd-turbo")

prompt = sys.argv[1] if len(sys.argv) > 1 else "a fox in a henhouse"

pipe.set_progress_bar_config(disable=True)

image = pipe(prompt=prompt, num_inference_steps=1, guidance_scale=0.0).images[0]
image.save("img.png")
imgcat(image)
