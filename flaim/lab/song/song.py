#!/usr/bin/env python

import warnings
warnings.filterwarnings("ignore")

import sys
import torch
import torchaudio
from diffusers import StableDiffusionPipeline
from diffusers import logging
import numpy as np
from PIL import Image
import soundcard as sc
import soundfile as sf

image_width = 512
sample_rate = 44100  # [Hz]
clip_duration_ms = 5000  # [ms]

bins_per_image = 512
n_mels = 512

# FFT parameters
window_duration_ms = 100  # [ms]
padded_duration_ms = 400  # [ms]
step_size_ms = 10  # [ms]

# Derived parameters
num_samples = int(image_width / float(bins_per_image) * clip_duration_ms) * sample_rate
n_fft = int(padded_duration_ms / 1000.0 * sample_rate)
hop_length = int(step_size_ms / 1000.0 * sample_rate)
win_length = int(window_duration_ms / 1000.0 * sample_rate)

logging.set_verbosity(50)
logging.disable_progress_bar()

def spectrogram_from_image(
    image: Image.Image, max_volume: float = 50, power_for_image: float = 0.25
) -> np.ndarray:

    data = np.array(image).astype(np.float32)
    data = data[::-1, :, 0]
    data = 255 - data
    data = data * max_volume / 255
    data = np.power(data, 1 / power_for_image)

    return data

def waveform_from_spectrogram(
    Sxx: np.ndarray,
    n_fft=n_fft,
    hop_length=hop_length,
    win_length=win_length,
    num_samples=num_samples,
    sample_rate=sample_rate,
    mel_scale: bool = True,
    n_mels: int = 512,
    max_mel_iters: int = 200,
    num_griffin_lim_iters: int = 32,
    device: str = "cpu",
) -> np.ndarray:

    Sxx_torch = torch.from_numpy(Sxx).to(device)

    if mel_scale:
        mel_inv_scaler = torchaudio.transforms.InverseMelScale(
            n_mels=n_mels,
            sample_rate=sample_rate,
            f_min=0,
            f_max=10000,
            n_stft=n_fft // 2 + 1,
            norm=None,
            mel_scale="htk",
            #max_iter=max_mel_iters,
        ).to(device)

        Sxx_torch = mel_inv_scaler(Sxx_torch)

    griffin_lim = torchaudio.transforms.GriffinLim(
        n_fft=n_fft,
        win_length=win_length,
        hop_length=hop_length,
        power=1.0,
        n_iter=num_griffin_lim_iters,
    ).to(device)

    waveform = griffin_lim(Sxx_torch).cpu().numpy()

    return waveform

if torch.cuda.is_available():
  pipe = StableDiffusionPipeline.from_pretrained("riffusion/riffusion-model-v1", torch_dtype=torch.float16, variant="fp16")
  pipe.to("cuda")
elif torch.backends.mps.is_available():
  pipe = StableDiffusionPipeline.from_pretrained("riffusion/riffusion-model-v1")
  pipe.to("mps")
else:
  pipe = StableDiffusionPipeline.from_pretrained("riffusion/riffusion-model-v1")

prompt = sys.argv[1] if len(sys.argv) > 1 else "a slow song with bagpipes"

pipe.set_progress_bar_config(disable=True)

image = pipe(prompt=prompt).images[0]
waveform = waveform_from_spectrogram(spectrogram_from_image(image))
normalized = waveform / np.max(np.abs(waveform))

sf.write(f"{prompt}.wav", normalized, samplerate=sample_rate)

default_speaker = sc.default_speaker()
default_speaker.play(normalized, samplerate=sample_rate)
