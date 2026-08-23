# syntax=docker/dockerfile:1
#
# NoobAI-XL V-Pred 1.0 を RunPod Serverless で動かすためのワーカー。
#
# 公式の worker-comfyui にチェックポイントを 1 本焼き込むだけの薄い派生で、
# handler も entrypoint も持たない。公式側の実装がそのまま動く。
#
# ワークフローは API の input.workflow で毎回渡す設計にしてある。V-Pred は
# CFG やサンプラーの選び方で結果が大きく変わるモデルなので、そこを
# イメージに固定してしまうと調整のたびにビルドを待つことになる。
#
# モデルはネットワークボリュームではなくイメージに焼き込む。ボリューム経由は
# 存在するだけで容量課金が続くうえ、コールドスタートも読み出しの分だけ遅い。
#
# 系統の違うモデルを 1 つのイメージに同居させない。以前 Qwen-Image-Edit
# (モデルだけで 29GB) と同居させたところ、ビルドが 30 分の打ち切りに
# 間に合わず完走しなかった。分けておけば、片方を更新しても
# もう片方のコールドスタートは重くならない。
#
# CUDA 12.8 向けにビルドされた PyTorch が入っている base を明示的に選ぶ。
# 素の 5.8.6-base は comfy-cli の既定でインストールされるため、より新しい
# CUDA 向けの PyTorch が入り、hub.json で 12.8 を指定したホストでは
# "no kernel image is available" で起動に失敗する。
FROM runpod/worker-comfyui:5.8.6-base-cuda12.8.1

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
#
# 取得はステージを分けず最終ステージで直接おこなう。モデルが 1 本しかないので
# 並列化の利得がなく、ステージを分けると 7.1GB がビルダ内に二重に置かれて
# CI ランナーの空き容量を圧迫する。取得先は base に必ず入っている wget で
# 固定する (comfy model download は配置先が comfy-cli の設定に依存する)。
RUN wget -q --tries=3 -O /comfyui/models/checkpoints/NoobAI-XL-Vpred-v1.0.safetensors \
      https://huggingface.co/Laxhar/noobai-XL-Vpred-1.0/resolve/main/NoobAI-XL-Vpred-v1.0.safetensors

# handler はベースイメージにも同じものが入っているが、RunPod Hub の掲載要件が
# リポジトリ内の handler.py を求めるため、明示的に置いて上書きする。
# 中身は worker-comfyui のものをそのまま使う (どちらも AGPL-3.0)。
COPY handler.py /handler.py
