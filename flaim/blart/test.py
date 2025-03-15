import torch
from diffusers import FluxPipeline

pipe = FluxPipeline.from_pretrained("black-forest-labs/FLUX.1-dev", torch_dtype=torch.bfloat16)
pipe.load_lora_weights("Shakker-Labs/FLUX.1-dev-LoRA-Logo-Design", weight_name="FLUX-dev-lora-Logo-Design.safetensors")
pipe.fuse_lora(lora_scale=0.8)
pipe.to("mps")

prompt = "logo,Minimalist,A bunch of grapes and a wine glass"
image = pipe(prompt, 
             num_inference_steps=24, 
             guidance_scale=3.5,
            ).images[0]
image.save(f"example.png")

