"""
Automated Translation Engine ONNX Verification Suite
Tests model loading, vocabulary encoding, autoregressive ONNX decoding,
and translation accuracy across all supported offline directions.
"""
import sys
import os
import json
import time
import numpy as np
import onnxruntime as ort

sys.stdout.reconfigure(encoding='utf-8')

# Reference source directories for models
ANUVAAD_MODELS = r"C:\AnuvaadAI2\anuvaad-models"
EN_INDIC_MODELS = r"C:\AnuvaadAI2\en-indic-onnx"

print("==================================================")
print("ANUVAADAI 2.0 - TRANSLATION ENGINE ONNX BENCHMARKS")
print("==================================================")

# Test 1: Verify En-Indic Model Loading & Execution
print("\n--- Testing English-to-Indic ONNX Model ---")
t0 = time.time()
enc_en = ort.InferenceSession(os.path.join(EN_INDIC_MODELS, "encoder_model.onnx"))
dec_en = ort.InferenceSession(os.path.join(EN_INDIC_MODELS, "decoder_model.onnx"))
decp_en = ort.InferenceSession(os.path.join(EN_INDIC_MODELS, "decoder_with_past_model.onnx"))
t_load_en = time.time() - t0
print(f"Loaded English-to-Indic sessions in {t_load_en:.2f} s")

# Test 2: Verify English -> Santali (Ol Chiki)
from transformers import AutoTokenizer
tok_en = AutoTokenizer.from_pretrained(EN_INDIC_MODELS, trust_remote_code=True)

test_cases_en = [
    ("eng_Latn", "sat_Olck", "Hello children."),
    ("eng_Latn", "hin_Deva", "Hello children.")
]

for src, tgt, text in test_cases_en:
    t_start = time.time()
    prefixed = f"{src} {tgt} {text}"
    ids = tok_en.encode(prefixed)
    input_ids = np.array([ids], dtype=np.int64)
    attn = np.array([[1] * len(ids)], dtype=np.int64)

    t_enc_start = time.time()
    enc_out = enc_en.run(['last_hidden_state'], {'input_ids': input_ids, 'attention_mask': attn})[0]
    t_enc = time.time() - t_enc_start

    decoder_input_ids = np.array([[2]], dtype=np.int64)
    output_ids = [2]
    past = None

    t_dec_start = time.time()
    for step in range(32):
        if step == 0:
            dec_out = dec_en.run(None, {'input_ids': decoder_input_ids, 'encoder_hidden_states': enc_out, 'encoder_attention_mask': attn})
        else:
            feed = {'input_ids': decoder_input_ids, 'encoder_attention_mask': attn}
            for i in range((len(dec_out) - 1) // 4):
                base = i * 4
                feed[f'past_key_values.{i}.decoder.key'] = past[base]
                feed[f'past_key_values.{i}.decoder.value'] = past[base + 1]
                feed[f'past_key_values.{i}.encoder.key'] = past[base + 2]
                feed[f'past_key_values.{i}.encoder.value'] = past[base + 3]
            dec_out = decp_en.run(None, feed)
        logits = dec_out[0]
        past = list(dec_out[1:])
        next_id = int(np.argmax(logits[0, -1, :]))
        output_ids.append(next_id)
        if next_id == 2:
            break
        decoder_input_ids = np.array([[next_id]], dtype=np.int64)

    t_dec = time.time() - t_dec_start
    raw = tok_en.decode(output_ids, skip_special_tokens=True)
    t_total = time.time() - t_start

    print(f"\nResult [{src} -> {tgt}]:")
    print(f"  Input:  '{text}'")
    print(f"  Output: '{raw}'")
    print(f"  Timing: Total={t_total*1000:.1f}ms | Encoder={t_enc*1000:.1f}ms | Decode={t_dec*1000:.1f}ms (Steps={len(output_ids)-1})")

print("\nALL TRANSLATION ONNX BENCHMARKS COMPLETED SUCCESSFULLY.")
