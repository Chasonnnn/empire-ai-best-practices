#!/bin/bash
# Empire AI end-to-end smoke test — run ON the cluster:
#   scp assets/smoke_test.sh empire:~ && ssh empire 'bash ~/smoke_test.sh'
# Validates: uv env at latest stable, internet-in-jobs, Lustre HF cache, --qos=test
# lane, sbatch round-trip. BERT-base x SST-2, 1 epoch, 1 GPU (~10 min, ~$0.10).
# Expected: "RESULT accuracy=0.92xx" (validated 2026-07-17: 0.9266, 27s train on
# 1x H100, Python 3.13.12 + torch 2.13.0+cu130). Self-configuring — nothing to edit.
set -e

INST=$(sacctmgr -nP show assoc user=$USER format=Account | head -1)
LUSTRE=/mnt/lustre/$INST/$USER
echo "== institution: $INST | lustre: $LUSTRE =="

echo "== uv + env (latest stable) =="
command -v ~/.local/bin/uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
uv venv --clear ~/venvs/smoke --python 3.13
source ~/venvs/smoke/bin/activate
uv pip install --quiet torch transformers datasets accelerate
python -c 'import torch,transformers; print("torch",torch.__version__,"| transformers",transformers.__version__)'

mkdir -p ~/bert_smoke ~/logs
cat > ~/bert_smoke/train_sst2.py <<'PYEOF'
import os, time, torch
from datasets import load_dataset
from transformers import (AutoTokenizer, AutoModelForSequenceClassification,
                          TrainingArguments, Trainer)

t0 = time.time()
print("gpu:", torch.cuda.get_device_name(0))
ds = load_dataset("nyu-mll/glue", "sst2")
tok = AutoTokenizer.from_pretrained("bert-base-uncased")
ds = ds.map(lambda b: tok(b["sentence"], truncation=True, max_length=128), batched=True)
model = AutoModelForSequenceClassification.from_pretrained("bert-base-uncased", num_labels=2)

def acc(p):
    return {"accuracy": float((p.predictions.argmax(-1) == p.label_ids).mean())}

args = TrainingArguments(
    output_dir=os.environ["SMOKE_OUT"],
    per_device_train_batch_size=64, per_device_eval_batch_size=256,
    num_train_epochs=1, bf16=True, eval_strategy="epoch",
    save_strategy="no", logging_steps=100, report_to=[])
tr = Trainer(model=model, args=args, train_dataset=ds["train"],
             eval_dataset=ds["validation"], processing_class=tok, compute_metrics=acc)
tr.train()
m = tr.evaluate()
print(f"RESULT accuracy={m['eval_accuracy']:.4f} elapsed={time.time()-t0:.0f}s")
PYEOF

cat > ~/bert_smoke/job.sbatch <<EOF2
#!/bin/bash
#SBATCH -A $INST
#SBATCH -p $INST
#SBATCH --qos=test
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH -t 00:30:00
#SBATCH -J bert_smoke
#SBATCH -o /mnt/home/%u/logs/%x-%j.out
export HF_HOME=$LUSTRE/hf SMOKE_OUT=$LUSTRE/bert_smoke_out
source ~/venvs/smoke/bin/activate
python ~/bert_smoke/train_sst2.py
EOF2

JOB=$(sbatch --parsable ~/bert_smoke/job.sbatch)
echo "== submitted job $JOB — watch with: sacct -j $JOB -X -o State,Elapsed; log: ~/logs/bert_smoke-$JOB.out =="
