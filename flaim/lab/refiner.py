#!/usr/bin/env python3

import warnings
warnings.filterwarnings("ignore")

from diffusers import DiffusionPipeline, DPMSolverMultistepScheduler, StableDiffusionLatentUpscalePipeline, logging
import torch
import sys
from imgcat import imgcat

logging.set_verbosity(50)
logging.disable_progress_bar()

if torch.cuda.is_available():
  device = "cuda"
elif torch.backends.mps.is_available():
  device = "mps"
else:
  device = ""

prompt = sys.argv[1] if len(sys.argv) > 1 else "happy students in a computer lab"
loaded_prompt = "concept art" + prompt + ", high quality, digital render, (magical), (nature), (futuristic), digital artwork, illustrative, painterly, matte painting, highly detailed"

print("\n🧼 Loading base pipeline...", end='', flush=True)
base = DiffusionPipeline.from_pretrained(
    "stabilityai/sd_xl_base_1.0_0.9vae", torch_dtype=torch.float16, variant="fp16", use_safetensors=True
).to(device)
print("done.")

base.scheduler = DPMSolverMultistepScheduler.from_config(base.scheduler.config)

print("😶‍🌫️ Creating initial latent...")
image = base(
    prompt=loaded_prompt,
    num_inference_steps=40,
    denoising_end=0.8,
    output_type="latent",
).images

print("\n🧼 Loading refiner pipeline...", end='', flush=True)
refiner = DiffusionPipeline.from_pretrained(
    "stabilityai/stable-diffusion-xl-refiner-1.0_0.9vae",
    text_encoder_2=base.text_encoder_2,
    vae=base.vae,
    torch_dtype=torch.float16,
    use_safetensors=True,
    variant="fp16",
).to(device)
print("done")

print("🎨 Refining...")

image = refiner(
    prompt=loaded_prompt,
    num_inference_steps=40,
    denoising_start=0.8,
    image=image,
).images[0]

print("\n🧼 Loading upscaler pipeline...", end='', flush=True)
upscaler = StableDiffusionLatentUpscalePipeline.from_pretrained("stabilityai/sd-x2-latent-upscaler", torch_dtype=torch.float16).to("mps")
print("done")

print("🧸 Upscaling image...")

upscaled_image = upscaler(
    prompt=prompt,
    image=image,
    num_inference_steps=20,
    guidance_scale=0,
).images[0]

cropped_image = upscaled_image.crop((24, 350, 2024, 1550))

cropped_image.save(f"{prompt}.png")
imgcat(cropped_image)
