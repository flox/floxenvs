#!/usr/bin/env python3

import warnings
warnings.filterwarnings("ignore")

import torch
import sys
from diffusers import StableDiffusion3Pipeline
from imgcat import imgcat
from diffusers import logging

logging.set_verbosity(0)
logging.disable_progress_bar()

if torch.cuda.is_available():
    device = "cuda"
elif torch.backends.mps.is_available():
    device = "mps"
else:
    device = ""

token = "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"

pipe = StableDiffusion3Pipeline.from_pretrained("stabilityai/stable-diffusion-3-medium-diffusers", torch_dtype=torch.float16, token=token)
pipe = pipe.to(device)
pipe.set_progress_bar_config(disable=True)

prompt = (
    sys.argv[1] if len(sys.argv) > 1 else "a computer lab filled with plants and vines"
)

image = pipe(
    prompt,
    negative_prompt="",
    num_inference_steps=18,
    guidance_scale=7.0,
).images[0]

imgcat(image)


