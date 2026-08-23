# syntax=docker/dockerfile:1
#
# NoobAI-XL V-Pred 1.0 を RunPod Serverless で動かすためのワーカー。
#
# 公式の worker-comfyui にチェックポイントを 1 本焼き込むだけの薄い派生で、
# handler も entrypoint も持たない。公式側の実装がそのまま動く。
#
# ワークフローは API の input.workflow で毎回渡す設計にしてある。V-Pred は
# CFG やサンプラーの選び方で結果が大きく変わるモデルなので、そこを
# イメージに固定してしまうと調整のたびに 20 分のビルドを待つことになる。
#
# モデルはネットワークボリュームではなくイメージに焼き込む。ボリューム経由は
# 存在するだけで容量課金が続くうえ、コールドスタートも読み出しの分だけ遅い。
#
# 系統の違うモデルを 1 つのイメージに同居させない。以前 Qwen-Image-Edit
# (モデルだけで 29GB) と同居させたところ、Hub のビルドが 30 分の打ち切りに
# 届かず完走しなかった。分けておけば、片方を更新しても
# もう片方のコールドスタートは重くならない。
FROM runpod/worker-comfyui:5.8.6-base-cuda12.8.1 AS base

# V-Prediction 版を選ぶ。eps 版と違い暗部と明部が飽和しないので、
# 背景を暗く沈めたまま顔だけを起こす指定が効く。
#
# checkpoint に v_pred と ztsnr のキーが入っており、ComfyUI は読み込み時に
# これを見て自動で V-Prediction に切り替える。ワークフロー側に
# ModelSamplingDiscrete を挟む必要はない。
#
# 4 ステップ化の DMD2 LoRA は載せない。cc-by-nc-4.0 で商用利用できないうえ、
# 4 ステップに落とすには CFG を 1 にする必要があり、ネガティブプロンプトが
# 完全に無視される。構図の破綻を弾けなくなるほうが損になる。
FROM base AS checkpoint
RUN mkdir -p /models/checkpoints \
 && wget -q --tries=3 -O /models/checkpoints/NoobAI-XL-Vpred-v1.0.safetensors \
      https://huggingface.co/Laxhar/noobai-XL-Vpred-1.0/resolve/main/NoobAI-XL-Vpred-v1.0.safetensors

FROM base

COPY --from=checkpoint /models/checkpoints/ /comfyui/models/checkpoints/

# handler はベースイメージにも同じものが入っているが、Hub の掲載要件が
# リポジトリ内の handler.py を求めるため、明示的に置いて上書きする。
# 中身は worker-comfyui のものをそのまま使う (どちらも AGPL-3.0)。
COPY handler.py /handler.py
