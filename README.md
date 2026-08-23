# runpod-noobai-xl

A RunPod Serverless worker for [NoobAI-XL V-Pred 1.0](https://huggingface.co/Laxhar/noobai-XL-Vpred-1.0). It is a thin derivative of [runpod-workers/worker-comfyui](https://github.com/runpod-workers/worker-comfyui) that bakes one checkpoint into the image — nothing more.

## Why V-Prediction

The eps variant saturates at both ends of the tonal range. Ask it for a portrait on a near-black background and the face flattens along with the background. V-Pred does not, which is what makes a dark, uniform backdrop usable as a design constraint rather than something to fight.

Its checkpoint carries the `v_pred` and `ztsnr` keys, so ComfyUI switches to V-Prediction when it loads the file. No `ModelSamplingDiscrete` node, no manual sampler override — the setup burden that this model is known for lands on WebUI users, not here.

## Why not the 4-step LoRA

The usual companion to this model is DMD2's 4-step SDXL LoRA. This image deliberately omits it, for two reasons.

It is `cc-by-nc-4.0`. That rules it out for anything commercial.

And reaching four steps means dropping CFG to 1, which makes the negative prompt inert. Framing constraints — `head out of frame`, `cropped`, `full body` — stop being enforced, so you get back the composition failures you were trying to prevent. Paying 30 steps to keep them working is the better trade whenever you are generating a handful of images rather than serving traffic.

## What's inside

| | |
| --- | --- |
| Base | `runpod/worker-comfyui:5.8.6-base-cuda12.8.1` |
| Checkpoint | `NoobAI-XL-Vpred-v1.0` (7.1 GB) |
| GPU | `ADA_24` / `ADA_32_PRO` (24 GB / 32 GB) |
| CUDA | 12.8 |

One model family per image. An earlier attempt bundled this checkpoint alongside Qwen-Image-Edit, whose weights alone are 29 GB; the RunPod Hub build stops at 30 minutes and never produced a tag. Keeping them apart also means updating one does not slow the other's cold start.

The base tag has to match the CUDA version you declare. `5.8.6-base` installs whatever PyTorch build comfy-cli defaults to, which is newer than CUDA 12.8; pairing it with `"allowedCudaVersions": ["12.8"]` gets you a worker that never starts. Use the `-cuda12.8.1` tag instead.

## Recommended settings

Straight from the model card, and worth following literally:

| | |
| --- | --- |
| Sampler | `euler` — **other samplers will not work properly** |
| Steps | 28–35 |
| CFG | 4–5 |
| Resolution | 832x1216, 896x1152, 1024x1024, 1152x896, 1216x832, 768x1344, 1344x768 |

Prompts follow Danbooru caption order: `<1girl/1boy>, <character>, <series>, <artists>, <special tags>, <general tags>`. The quality prefix is `masterpiece, best quality, newest, absurdres, highres, safe`.

## Usage

Pass a workflow in [ComfyUI API format](https://github.com/runpod-workers/worker-comfyui#getting-the-workflow-json) as `input.workflow`. Nothing is fixed inside the image, so CFG, sampler, step count and output size are all decided per request.

```jsonc
{
  "input": {
    "workflow": { /* ComfyUI API format */ }
  }
}
```

## License

The worker code is AGPL-3.0, inherited from worker-comfyui.

The checkpoint is distributed under the [Fair AI Public License 1.0-SD](https://freedevproject.org/faipl-1.0-sd/). Its Output section states that "the output of this software is not covered by this license, and no contributor claims any rights to it" — generated images carry no license obligation.
