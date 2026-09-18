import os, time, math
threshold = float(os.environ["SMOKE_MIN_ACCURACY"])
if not math.isfinite(threshold) or not 0 <= threshold <= 1:
    raise ValueError("invalid accuracy threshold")
import torch
from datasets import load_dataset
from transformers import (AutoTokenizer, AutoModelForSequenceClassification,
                          TrainingArguments, Trainer)

t0 = time.time()
print("gpu:", torch.cuda.get_device_name(0))
ds = load_dataset("nyu-mll/glue", "sst2", revision=os.environ["DATASET_REVISION"])
tok = AutoTokenizer.from_pretrained("bert-base-uncased", revision=os.environ["MODEL_REVISION"])
ds = ds.map(lambda b: tok(b["sentence"], truncation=True, max_length=128), batched=True)
model = AutoModelForSequenceClassification.from_pretrained("bert-base-uncased", num_labels=2, revision=os.environ["MODEL_REVISION"])

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
import json, math
accuracy = float(m['eval_accuracy'])
if not math.isfinite(accuracy) or accuracy < threshold:
    raise RuntimeError(f"Smoke accuracy {accuracy} below declared acceptance threshold")
with open(os.path.join(os.environ['SMOKE_OUT'], 'result.json'), 'w') as result:
    json.dump({'status': 'passed', 'accuracy': accuracy}, result)
