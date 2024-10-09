#!/usr/bin/env python

import warnings
warnings.filterwarnings("ignore")

import sys
import torch
from imgcat import imgcat
from diffusers import AnimateDiffPipeline, MotionAdapter, EulerDiscreteScheduler
from diffusers.utils import export_to_gif
from huggingface_hub import hf_hub_download
from safetensors.torch import load_file
from diffusers import logging

logging.set_verbosity(50)
logging.disable_progress_bar()

if torch.cuda.is_available():
  device = "cuda"
elif torch.backends.mps.is_available():
  device = "mps"
else:
  device = "cpu"

adapter = MotionAdapter().to(device, torch.float16)
adapter.load_state_dict(load_file(hf_hub_download("ByteDance/AnimateDiff-Lightning","animatediff_lightning_2step_diffusers.safetensors"), device=device))

pipe = AnimateDiffPipeline.from_pretrained("emilianJR/epiCRealism", motion_adapter=adapter, torch_dtype=torch.float16).to(device)
pipe.scheduler = EulerDiscreteScheduler.from_config(pipe.scheduler.config, timestep_spacing="trailing", beta_schedule="linear")

prompt = sys.argv[1] if len(sys.argv) > 1 else "a fox in a henhouse"

#pipe.set_progress_bar_config(disable=True)
output = pipe(prompt=prompt, guidance_scale=1.0, num_inference_steps=3)

export_to_gif(output.frames[0], f"{prompt}.gif")
imgcat(open(f"{prompt}.gif"))
