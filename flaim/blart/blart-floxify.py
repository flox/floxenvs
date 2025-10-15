#!/usr/bin/env python3

import os
token = os.environ.get('HF_TOKEN')

# sssshhhhhhhhh if we wanna see you talk we'll run the notebook
import warnings

warnings.filterwarnings("ignore")

# we need a whole buncha diffuser tools
from diffusers import (
    StableDiffusionLatentUpscalePipeline,
    EulerAncestralDiscreteScheduler,
    logging,  # for more of the shutup
    StableDiffusionInstructPix2PixPipeline,
)

# we need torch as our diffuser backend
import torch

# grab some image tools
from PIL import Image
import sys
import gc
from pathlib import Path

# stuff for UI
from rich import print
from rich.panel import Panel
from rich.prompt import Prompt

# here's that more shutup we talked about
logging.set_verbosity(50)
logging.disable_progress_bar()

# draw images in the terminal
def draw(image):
    import tempfile
    import subprocess
    import os
    with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as temp_file:
        output_file = temp_file.name
        image.save(output_file)

    subprocess.run(['viu', output_file], check=True)
    os.remove(output_file)

# set our device and nope out if we don't have either CUDA or Metal
if torch.cuda.is_available():
    device = "cuda"
elif torch.backends.mps.is_available():
    device = "mps"
else:
    print("GPU acceleration is required.")
    exit(1)


# Grab ^C and be nice with it
try:
    print("\n")

    # get the input image path from argv, or prompt for it
    input_image_path = (
        sys.argv[1]
        if len(sys.argv) > 1
        else Prompt.ask(
            "Path to input image",
        )
    )

    # load and prepare the input image
    if not input_image_path or not input_image_path.strip():
        print("[red]Error: Input image path is required[/red]")
        exit(1)

    try:
        init_image = Image.open(input_image_path).convert("RGB").resize((1024, 1024))
        print(f"\nLoaded input image from: {input_image_path}")
        draw(init_image)
    except Exception as e:
        print(f"\n[red]Error loading image: {e}[/red]")
        exit(1)

    # Generate output filename based on input filename
    input_path = Path(input_image_path)
    output_filename = input_path.stem + "b" + ".webp"

    # Simple prompt for upscaler guidance
    simple_prompt = "high quality digital artwork"
    negative_prompt = "nsfw, cartoon, bad quality, bad anatomy, worst quality, low quality, low resolutions, extra fingers, blur, blurry, ugly, wrong proportions, watermark, image artifacts, lowres, ugly, jpeg artifacts, deformed, noisy image"

    print("\n")
    print(
        Panel(
            "Frambulating [red]Floxifier[/red] :slot_machine: to enhance image..."
        )
    )

    # Load the instruct pix2pix pipeline
    pipe = StableDiffusionInstructPix2PixPipeline.from_pretrained(
        "timbrooks/instruct-pix2pix", torch_dtype=torch.float16, safety_checker=None
    )
    pipe.to(device)
    pipe.scheduler = EulerAncestralDiscreteScheduler.from_config(pipe.scheduler.config)

    print("\n")
    print(Panel("Floxifying with [pink]stupid abandon[/pink] :dizzy_face: ..."))

    # this is the magic prompt that makes it look like flox, ssh, don't tell anyone
    instructprompt = "amazing, high quality, dreamlike, futuristic, colorful, vibrant"
    image = pipe(
        instructprompt,
        image=init_image,
        num_inference_steps=15,
        image_guidance_scale=1,
    ).images[0]

    # make another comp that shows a left/right of the before and after images
    refinercomp = Image.new("RGB", (2000, 600))
    refinercomp.paste(init_image, (0, -212))
    refinercomp.paste(image, (1000, -212))

    print("\n")
    draw(refinercomp)

    # at this point I have found that we need to do some garbage collection;
    # the refiner needs a lot of memory
    pipe = None
    if device == "cuda":
        torch.cuda.empty_cache()
    if device == "mps":
        torch.mps.empty_cache()
        torch.mps.current_allocated_memory()
    gc.collect()

    print("\n")
    print(Panel("Calling forth robotic upscaler :robot: ..."))

    # grab and run the stable diffusion 2x upscaler
    upscaler = StableDiffusionLatentUpscalePipeline.from_pretrained(
        "stabilityai/sd-x2-latent-upscaler", torch_dtype=torch.float16
    ).to(device)

    upscaled_image = upscaler(
        prompt=simple_prompt,
        negative_prompt=negative_prompt,
        image=image,
        num_inference_steps=20,
        guidance_scale=0,
    ).images[0]

    # crop to our final dimensions
    cropped_image = upscaled_image.crop(
        (24, 424, 2024, 1624)
    )  # from 2048/1024 to 2000/1200

    print("\n")
    draw(cropped_image)
    print("\n")

    # export with filename based on input image
    cropped_image.save(output_filename, "webp", quality=50)
    print(f"[green]Saved to: {output_filename}[/green]\n")
    exit(0)

except KeyboardInterrupt:
    print("\nOkay bye bye!\n")
    exit(1)
