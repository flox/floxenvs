#!/usr/bin/env python3

import warnings
warnings.filterwarnings("ignore")

from diffusers import (
    StableDiffusionXLPipeline,
    KDPM2AncestralDiscreteScheduler,
    StableDiffusionLatentUpscalePipeline,
    AutoencoderKL,
    EDMDPMSolverMultistepScheduler,
#    logging,
)
import torch
import sys
from imgcat import imgcat

#logging.set_verbosity(50)
#logging.disable_progress_bar()

if torch.cuda.is_available():
    device = "cuda"
elif torch.backends.mps.is_available():
    device = "mps"
else:
    device = ""

prompt = sys.argv[1] if len(sys.argv) > 1 else "a computer lab filled with plants and vines"
loaded_prompt = (
    "concept art"
    + prompt
    + ", high quality, digital render, (magical), (nature), (futuristic), digital artwork, highly detailed"
)
negative_prompt = "nsfw, bad quality, bad anatomy, worst quality, low quality, low resolutions, extra fingers, blur, blurry, ugly, wrongs proportions, watermark, image artifacts, lowres, ugly, jpeg artifacts, deformed, noisy image"

# Load VAE component
vae = AutoencoderKL.from_pretrained(
    "madebyollin/sdxl-vae-fp16-fix", torch_dtype=torch.float16
)

# Configure the pipeline
pipe = StableDiffusionXLPipeline.from_pretrained(
    "dataautogpt3/ProteusV0.4", vae=vae, torch_dtype=torch.float16
)

#pipe.set_progress_bar_config(disable=True)
pipe.scheduler = KDPM2AncestralDiscreteScheduler.from_config(pipe.scheduler.config)
pipe.to(device)

image = pipe(
    prompt,
    negative_prompt=negative_prompt,
    width=1024,
    height=1024,
    guidance_scale=7.5,
    num_inference_steps=50,
).images[0]

upscaler = StableDiffusionLatentUpscalePipeline.from_pretrained(
    "stabilityai/sd-x2-latent-upscaler", torch_dtype=torch.float16
).to(device)
#upscaler.set_progress_bar_config(disable=True)

upscaled_image = upscaler(
    prompt=prompt,
    image=image,
    num_inference_steps=20,
    guidance_scale=0,
).images[0]

cropped_image = upscaled_image.crop((24, 350, 2024, 1550))

cropped_image.save(f"{prompt}.png")
imgcat(cropped_image)
