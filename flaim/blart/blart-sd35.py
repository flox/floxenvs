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

    # get the prompt from argv, or use a default
    prompt = (
        sys.argv[1]
        if len(sys.argv) > 1
        else Prompt.ask(
            "What is your prompt?",
            default="aircraft hanger with fish",
        )
    )

    # load up the prompt a bit with some opinions
    loaded_prompt = (
        "concept art "
        + prompt
        + ", high quality, (magical), (nature), (futuristic), digital artwork, (comic book)"
    )
    negative_prompt = "nsfw, cartoon, bad quality, bad anatomy, worst quality, low quality, low resolutions, extra fingers, blur, blurry, ugly, wrong proportions, watermark, image artifacts, lowres, ugly, jpeg artifacts, deformed, noisy image, person"

    print("\n")
    print(
        Panel(
            "Conjuring [purple]proto image generator[/purple] :mag: from the ether..."
        )
    )

    model_id = "stabilityai/stable-diffusion-3.5-large-turbo"

    if device == "cuda":
        from diffusers import BitsAndBytesConfig
        nf4_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.bfloat16
        )
        model_nf4 = SD3Transformer2DModel.from_pretrained(
            model_id,
            subfolder="transformer",
            quantization_config=nf4_config,
            torch_dtype=torch.bfloat16,
            token=token
        )
    
        t5_nf4 = T5EncoderModel.from_pretrained("diffusers/t5-nf4", torch_dtype=torch.bfloat16, token=token)
    
        pipe = StableDiffusion3Pipeline.from_pretrained(
            model_id, 
            transformer=model_nf4,
            text_encoder_3=t5_nf4,
            torch_dtype=torch.bfloat16,
            token=token
        )
        pipe.enable_model_cpu_offload()
    else:
        pipe = StableDiffusion3Pipeline.from_pretrained(
            model_id, 
            torch_dtype=torch.bfloat16,
            token=token
        )
        pipe.to('mps')

    chosenproto = -1

    while chosenproto == -1:
        print("\n")
        print(Panel("Generating [blue]proto image selections[/blue] :dizzy: ..."))

        # make some prototype images
        protoimages = pipe(
            loaded_prompt,
            negative_prompt=negative_prompt,
            num_images_per_prompt=3,
            width=1024,
            height=1024,
            guidance_scale=0.0,
            max_sequence_length=512,
            num_inference_steps=4,
        ).images

        print("\n")

        # make a quick comp of the proto images so the user can see them
        # when we do this, crop the top and bottom so the image composition
        # will be close to the final aspect ratio
        protocomp = Image.new("RGB", (3072, 600))

        x_offset = 0
        for im in protoimages:
            protocomp.paste(im, (x_offset, -212))
            x_offset += im.size[0]

        draw(protocomp)
        print("\n")

        # ask the user to choose a proto
        gr = HorizontalOptionGroup(
            "What image should we refine?",
            NumberOption("Start over!"),
            NumberOption("Image 1"),
            NumberOption("Image 2"),
            NumberOption("Image 3"),
        )
        gr.setMaxOptionPerUnit(4)
        user_input = gr.ask()

        chosenproto = int(user_input.getOpt()) - 1

    print("\n")
    print(
        Panel(
            "Frambulating [red]Floxifier[/red] :slot_machine: to refine image "
            + user_input.getOpt()
            + " ..."
        )
    )

    # at this point I have found that we need to do some garbage collection;
    # that instruct-pix2pix is no little thing
    pipe = None
    if device == "cuda":
        torch.cuda.empty_cache()
    if device == "mps":
        torch.mps.empty_cache()
        torch.mps.current_allocated_memory()
    gc.collect()

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
        image=protoimages[chosenproto],
        num_inference_steps=15,
        image_guidance_scale=1,
    ).images[0]

    # make another comp that shows a left/right of the before and after images
    refinercomp = Image.new("RGB", (2000, 600))
    refinercomp.paste(protoimages[chosenproto], (0, -212))
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

    # export in two formats
    cropped_image.save(f"{prompt}.webp", "webp", quality=50)
    exit(0)

except KeyboardInterrupt:
    print("\nOkay bye bye!\n")
    exit(1)
