import os
import sys
import json
import numpy as np
import onnxruntime as ort
import sentencepiece as spm

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

MODEL_DIR = r"C:\AnuvaadAI Anti\indic-en-models"

# 1. Load tokenizers
print("Loading SentencePiece models and vocabularies...")
sp_src = spm.SentencePieceProcessor()
sp_src.load(os.path.join(MODEL_DIR, "model.SRC"))

sp_tgt = spm.SentencePieceProcessor()
sp_tgt.load(os.path.join(MODEL_DIR, "model.TGT"))

with open(os.path.join(MODEL_DIR, "dict.SRC.json"), "r", encoding="utf-8") as f:
    dict_src = json.load(f)

with open(os.path.join(MODEL_DIR, "dict.TGT.json"), "r", encoding="utf-8") as f:
    dict_tgt = json.load(f)

rev_dict_tgt = {int(v): k for k, v in dict_tgt.items()}

def encode_src(text, src_lang, tgt_lang):
    # IndicTrans format:
    # [src_lang, tgt_lang] + pieces + [</s>]
    pieces = sp_src.encode_as_pieces(text)
    ids = [dict_src[src_lang], dict_src[tgt_lang]]
    unk_id = dict_src.get("<unk>", 3)
    for p in pieces:
        # replace standard SPM   with ▁ if needed
        p_sub = p.replace(' ', '▁')
        ids.append(dict_src.get(p_sub, dict_src.get(p, unk_id)))
    ids.append(dict_src["</s>"])
    return ids

def decode_tgt(token_ids):
    tokens = []
    for tid in token_ids:
        if tid in (0, 1, 2): # pad, unk, eos
            continue
        tok = rev_dict_tgt.get(tid, "")
        if tok.startswith("__") and tok.endswith("__"):
            continue
        tokens.append(tok)
    text = sp_tgt.decode_pieces(tokens)
    return text

# 2. Initialize ONNX sessions
print("Initializing ONNX sessions...")
sess_opts = ort.SessionOptions()
sess_opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL

encoder_path = os.path.join(MODEL_DIR, "encoder_model.onnx")
prefill_path = os.path.join(MODEL_DIR, "decoder_model.onnx")
cached_path = os.path.join(MODEL_DIR, "decoder_with_past_model.onnx")

sess_enc = ort.InferenceSession(encoder_path, sess_opts, providers=["CPUExecutionProvider"])
sess_prefill = ort.InferenceSession(prefill_path, sess_opts, providers=["CPUExecutionProvider"])
sess_cached = ort.InferenceSession(cached_path, sess_opts, providers=["CPUExecutionProvider"])

print("Encoder inputs:", [i.name for i in sess_enc.get_inputs()])
print("Encoder outputs:", [o.name for o in sess_enc.get_outputs()])
print("Prefill inputs:", [i.name for i in sess_prefill.get_inputs()])
print("Cached inputs:", [i.name for i in sess_cached.get_inputs()][:6], "...")

def translate(text, src_lang="hin_Deva", tgt_lang="eng_Latn"):
    input_ids = encode_src(text, src_lang, tgt_lang)
    S = len(input_ids)
    input_ids_arr = np.array([input_ids], dtype=np.int64)
    attention_mask_arr = np.ones((1, S), dtype=np.int64)

    # Run encoder
    enc_out = sess_enc.run(None, {
        "input_ids": input_ids_arr,
        "attention_mask": attention_mask_arr
    })
    # last_hidden_state or encoder_hidden
    enc_hidden = enc_out[0] # (1, S, 512)

    # Prefill step
    dec_input_ids = np.array([[2]], dtype=np.int64) # decoder start token
    prefill_feed = {
        "input_ids": dec_input_ids,
        "encoder_hidden_states": enc_hidden,
        "encoder_attention_mask": attention_mask_arr
    }
    prefill_out = sess_prefill.run(None, prefill_feed)
    logits = prefill_out[0]
    first_token = int(np.argmax(logits[0, -1, :]))

    # Past key values
    # prefill output names: [logits, present.0.decoder.key, present.0.decoder.value, ...]
    out_names = [o.name for o in sess_prefill.get_outputs()]
    past_dict = {}
    for name, val in zip(out_names[1:], prefill_out[1:]):
        cached_name = name.replace("present.", "past_key_values.")
        past_dict[cached_name] = val

    generated = [first_token]
    cur_token = first_token

    max_steps = 50
    while len(generated) < max_steps and cur_token != 2:
        feed = {
            "input_ids": np.array([[cur_token]], dtype=np.int64),
            "encoder_attention_mask": attention_mask_arr
        }
        for k, v in past_dict.items():
            feed[k] = v
        out = sess_cached.run(None, feed)
        logits = out[0]
        next_token = int(np.argmax(logits[0, -1, :]))
        generated.append(next_token)
        out_c_names = [o.name for o in sess_cached.get_outputs()]
        for name, val in zip(out_c_names[1:], out[1:]):
            cached_name = name.replace("present.", "past_key_values.")
            past_dict[cached_name] = val
        cur_token = next_token

    return decode_tgt(generated)

test_sentences = [
    ("नमस्ते दुनिया", "hin_Deva", "eng_Latn"),
    ("आप कैसे हैं?", "hin_Deva", "eng_Latn"),
    ("भारत एक महान देश है।", "hin_Deva", "eng_Latn"),
    ("ᱥᱟᱹᱜᱩᱱ ᱡᱚᱦᱟᱨ", "sat_Olck", "eng_Latn"),
    ("ᱟᱢ ᱪᱮᱫ ᱞᱮᱠᱟ ᱢᱮᱱᱟᱢᱟ?", "sat_Olck", "eng_Latn"),
]

print("\n--- RUNNING TRANSLATION TESTS ---")
for text, s, t in test_sentences:
    res = translate(text, s, t)
    print(f"[{s} -> {t}] '{text}' => '{res}'")
