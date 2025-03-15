#!/usr/bin/env python3

import os
token = os.environ.get('HF_TOKEN')

# sssshhhhhhhhh if we wanna see you talk we'll run the notebook
import warnings

warnings.filterwarnings("ignore")

# we need a whole buncha diffuser tools
from diffusers import (
    StableDiffusionXLPipeline,
    StableDiffusionLatentUpscalePipeline,
    EulerAncestralDiscreteScheduler,
    AutoencoderKL,
    logging,  # for more of the shutup
    StableDiffusionInstructPix2PixPipeline,
    StableDiffusion3Pipeline,
    SD3Transformer2DModel
)
from diffusers.utils import load_image
from transformers import T5EncoderModel

# we need torch as our diffuser backend
import torch

# grab some image tools
from PIL import Image
import sys
import gc

# stuff for UI
from fancyInput import HorizontalOptionGroup, NumberOption
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

    # get the infile from argv, or use a default
    infile = (
        sys.argv[1]
        if len(sys.argv) > 1
        else Prompt.ask(
            "What is the name of your input file?",
            default="infile.png",
        )
    )

    image = load_image(infile)
    mounted_image = Image.new("RGB", (1024, 1024))

    if image.width > image.height:
        aspect_ratio = 1024 / float(image.width)
        new_size = (1024, int(image.height * aspect_ratio))
        resized_image = image.resize(new_size)
        mounted_image.paste(resized_image, (0, int((1024-resized_image.height)/2)))
    elif image.width == image.height:
        resized_image = image.resize((1024,1024))
        mounted_image.paste(resized_image, (0, 0))
    else:
        aspect_ratio = 1024 / float(image.height)
        new_size = (int(image.width * aspect_ratio), 1024)
        resized_image = image.resize(new_size)
        mounted_image.paste(resized_image, (int((1024-resized_image.width)/2)), 0)

    print(
        Panel(
            "Frambulating [red]Floxifier[/red] :slot_machine: to refine image "
            + infile
            + " ..."
        )
    )

    inputcomp = Image.new("RGB", (1000, 600))
    inputcomp.paste(mounted_image, (0, -212))
    draw(inputcomp)
    
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
        image=mounted_image,
        num_inference_steps=15,
        image_guidance_scale=1,
    ).images[0]

    # make another comp that shows a left/right of the before and after images
    refinercomp = Image.new("RGB", (2000, 600))
    refinercomp.paste(mounted_image, (0, -212))
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

    loaded_prompt = "concept art, high quality, (magical), (nature), (futuristic), digital artwork, (comic book)"
    negative_prompt = "nsfw, cartoon, bad quality, bad anatomy, worst quality, low quality, low resolutions, extra fingers, blur, blurry, ugly, wrong proportions, watermark, image arti facts, lowres, ugly, jpeg artifacts, deformed, noisy image, person"

    upscaled_image = upscaler(
        prompt=loaded_prompt,
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

    outfile = os.path.splitext(infile)[0] + "-floxified"

    # export in two formats
    cropped_image.save(f"{outfile}.webp", "webp", quality=50)
    exit(0)

except KeyboardInterrupt:
    print("\nOkay bye bye!\n")
    exit(1)
