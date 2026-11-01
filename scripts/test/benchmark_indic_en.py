import os
import sys
import json
import time
import tracemalloc
import numpy as np
import onnxruntime as ort
import sentencepiece as spm

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

MODEL_DIR = r"C:\AnuvaadAI Anti\indic-en-models"

print("=" * 60)
print("Indic-to-English Benchmark & Precision Evaluation Audit")
print("=" * 60)

# Memory & Session tracking
tracemalloc.start()
t_init_start = time.perf_counter()

sp_src = spm.SentencePieceProcessor()
sp_src.load(os.path.join(MODEL_DIR, "model.SRC"))

sp_tgt = spm.SentencePieceProcessor()
sp_tgt.load(os.path.join(MODEL_DIR, "model.TGT"))

with open(os.path.join(MODEL_DIR, "dict.SRC.json"), "r", encoding="utf-8") as f:
    dict_src = json.load(f)

with open(os.path.join(MODEL_DIR, "dict.TGT.json"), "r", encoding="utf-8") as f:
    dict_tgt = json.load(f)

rev_dict_tgt = {int(v): k for k, v in dict_tgt.items()}

sess_opts = ort.SessionOptions()
sess_opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL

sess_enc = ort.InferenceSession(os.path.join(MODEL_DIR, "encoder_model.onnx"), sess_opts, providers=["CPUExecutionProvider"])
sess_prefill = ort.InferenceSession(os.path.join(MODEL_DIR, "decoder_model.onnx"), sess_opts, providers=["CPUExecutionProvider"])
sess_cached = ort.InferenceSession(os.path.join(MODEL_DIR, "decoder_with_past_model.onnx"), sess_opts, providers=["CPUExecutionProvider"])

t_init_end = time.perf_counter()
current_mem, peak_mem = tracemalloc.get_traced_memory()
print(f"Session Initialization Time: {(t_init_end - t_init_start)*1000:.1f} ms")
print(f"Model Load Traced RAM: {current_mem / 1024 / 1024:.2f} MB (Peak: {peak_mem / 1024 / 1024:.2f} MB)")

def encode_src(text, src_lang, tgt_lang):
    pieces = sp_src.encode_as_pieces(text)
    ids = [dict_src[src_lang], dict_src[tgt_lang]]
    unk_id = dict_src.get("<unk>", 3)
    for p in pieces:
        p_sub = p.replace(' ', '▁')
        ids.append(dict_src.get(p_sub, dict_src.get(p, unk_id)))
    ids.append(dict_src["</s>"])
    return ids

def decode_tgt(token_ids):
    pieces = []
    for tid in token_ids:
        if tid in (0, 1, 2): continue
        tok = rev_dict_tgt.get(tid, "")
        if tok.startswith("<") and tok.endswith(">"): continue
        pieces.append(tok)
    # decode pieces with SentencePiece logic
    sb = []
    for p in pieces:
        if p.startswith("▁"):
            if sb: sb.append(" ")
            sb.append(p[1:])
        elif p.startswith(" "):
            if sb: sb.append(" ")
            sb.append(p[1:])
        else:
            sb.append(p)
    return "".join(sb).strip()

def run_translation(text, src_lang, tgt_lang="eng_Latn", max_tokens=80):
    t0 = time.perf_counter()
    input_ids = encode_src(text, src_lang, tgt_lang)
    S = len(input_ids)
    input_ids_arr = np.array([input_ids], dtype=np.int64)
    attention_mask_arr = np.ones((1, S), dtype=np.int64)

    t_enc_start = time.perf_counter()
    enc_out = sess_enc.run(None, {
        "input_ids": input_ids_arr,
        "attention_mask": attention_mask_arr
    })
    enc_hidden = enc_out[0]
    t_enc_ms = (time.perf_counter() - t_enc_start) * 1000

    t_pre_start = time.perf_counter()
    dec_input_ids = np.array([[2]], dtype=np.int64)
    prefill_out = sess_prefill.run(None, {
        "input_ids": dec_input_ids,
        "encoder_hidden_states": enc_hidden,
        "encoder_attention_mask": attention_mask_arr
    })
    logits = prefill_out[0]
    first_token = int(np.argmax(logits[0, -1, :]))

    out_names = [o.name for o in sess_prefill.get_outputs()]
    past_dict = {}
    for name, val in zip(out_names[1:], prefill_out[1:]):
        cached_name = name.replace("present.", "past_key_values.")
        past_dict[cached_name] = val

    t_pre_ms = (time.perf_counter() - t_pre_start) * 1000

    generated = [first_token]
    cur_token = first_token
    decode_steps = 0

    t_dec_start = time.perf_counter()
    while len(generated) < max_tokens and cur_token != 2:
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
        decode_steps += 1

    t_dec_ms = (time.perf_counter() - t_dec_start) * 1000
    total_ms = (time.perf_counter() - t0) * 1000

    translated_text = decode_tgt(generated)
    return {
        "text": translated_text,
        "token_count": len(generated),
        "decode_steps": decode_steps,
        "enc_ms": t_enc_ms,
        "pre_ms": t_pre_ms,
        "dec_ms": t_dec_ms,
        "total_ms": total_ms
    }

hindi_sentences = [
    ("नमस्ते।", "Short Greeting"),
    ("धन्यवाद।", "Short Courtesy"),
    ("हाँ, मैं तैयार हूँ।", "Short Response"),
    ("शुभ प्रभात।", "Short Salutation"),
    ("आपका नाम क्या है?", "Question"),
    ("क्या आप मेरी मदद कर सकते हैं?", "Question"),
    ("यह स्कूल कहाँ स्थित है?", "Question"),
    ("आज कौन सा पाठ पढ़ाया जाएगा?", "Question"),
    ("कक्षा 5 में 42 छात्र और 3 शिक्षक हैं।", "Numbers & Stats"),
    ("वर्ष 2026 में 15 अगस्त को 79वां स्वतंत्रता दिवस मनाया जाएगा।", "Numbers & Dates"),
    ("एक सप्ताह में 7 दिन और एक वर्ष में 365 दिन होते हैं।", "Numbers & Calendar"),
    ("विज्ञान हमें प्रकृति और पर्यावरण को समझने में मदद करता है।", "Educational Science"),
    ("गणित में जोड़, घटाव, गुणा और भाग बुनियादी संक्रियाएँ हैं।", "Educational Math"),
    ("सूर्य के प्रकाश से पौधे अपना भोजन प्रकाश संश्लेषण द्वारा बनाते हैं।", "Educational Biology"),
    ("पानी को उबालकर पीने से कई बीमारियाँ दूर रहती हैं।", "Health & Hygiene"),
    ("प्राथमिक शिक्षा प्रत्येक बच्चे का मौलिक अधिकार है और इसे मातृभाषा में देना सर्वाधिक प्रभावी माना गया है।", "Long Policy"),
    ("गाँव की पाठशाला में बच्चे रोज सुबह प्रार्थना करते हैं और उसके बाद अपनी कक्षाओं में बैठकर पढ़ाई करते हैं।", "Long Descriptive"),
    ("पर्यावरण की रक्षा के लिए हमें अधिक से अधिक पेड़ लगाने चाहिए और प्लास्टिक का उपयोग तुरंत बंद करना चाहिए।", "Long Civic"),
    ("कृपया अपनी पाठ्यपुस्तक का पृष्ठ संख्या 25 खोलें और पहला पैराग्राफ ध्यानपूर्वक पढ़ें।", "Educational Instructional"),
    ("जब शिक्षक ने ब्लैकबोर्ड पर नया सवाल लिखा, तो सभी विद्यार्थियों ने अपनी उत्तर पुस्तिकाओं में हल करना शुरू किया।", "Complex Classroom Narrative")
]

santali_sentences = [
    ("ᱥᱟᱹᱜᱩᱱ ᱡᱚᱦᱟᱨ ᱾", "Short Greeting"),
    ("ᱥᱟᱨᱦᱟᱣ ᱾", "Short Courtesy"),
    ("ᱦᱮᱸ, ᱤᱧ ᱛᱮᱭᱟᱨ ᱢᱮᱱᱟᱹᱧᱟ ᱾", "Short Response"),
    ("ᱥᱟᱹᱜᱩᱱ ᱥᱮᱛᱟᱜ ᱾", "Short Salutation"),
    ("ᱟᱢᱟᱜ ᱧᱩᱛᱩᱢ ᱫᱚ ᱪᱮᱫ?", "Question"),
    ("ᱟᱢ ᱪᱮᱫ ᱞᱮᱠᱟ ᱢᱮᱱᱟᱢᱟ?", "Question"),
    ("ᱱᱚᱶᱟ ᱟᱥᱲᱟ ᱫᱚ ᱚᱠᱟᱨᱮ ᱢᱮᱱᱟᱜᱼᱟ?", "Question"),
    ("ᱛᱮᱦᱮᱧ ᱫᱚ ᱪᱮᱫ ᱵᱚᱱ ᱯᱟᱲᱦᱟᱣᱜᱼᱟ?", "Question"),
    ("ᱠᱞᱟᱥ ᱕ ᱨᱮ ᱔᱒ ᱜᱚᱴᱟᱝ ᱯᱟᱹᱴᱷᱩᱣᱟᱹ ᱟᱨ ᱓ ᱡᱚᱱᱟ ᱜᱟᱞᱚᱪᱤᱭᱟᱹ ᱢᱮᱱᱟᱜ ᱠᱚᱣᱟ ᱾", "Numbers & Stats"),
    ("ᱢᱤᱫ ᱦᱟᱯᱛᱟ ᱨᱮ ᱗ ᱢᱟᱦᱟᱸ ᱟᱨ ᱢᱤᱫ ᱥᱮᱨᱢᱟ ᱨᱮ ᱓᱖᱕ ᱢᱟᱦᱟᱸ ᱛᱟᱦᱮᱸᱱᱟ ᱾", "Numbers & Calendar"),
    ("ᱱᱚᱶᱟ ᱯᱩᱛᱷᱤ ᱨᱮ ᱑᱒᱐ ᱥᱟᱦᱴᱟ ᱢᱮᱱᱟᱜᱼᱟ ᱾", "Numbers & Measure"),
    ("ᱥᱟᱬᱮᱥ ᱫᱚ ᱟᱵᱚ ᱫᱷᱟᱹᱨᱛᱤ ᱟᱨ ᱯᱚᱨᱤᱵᱮᱥ ᱵᱩᱡᱷᱟᱹᱣ ᱨᱮ ᱜᱚᱲᱚ ᱮᱢᱟᱵᱚᱱᱟ ᱾", "Educational Science"),
    ("ᱚᱞ ᱪᱤᱠᱤ ᱫᱚ ᱥᱟᱱᱛᱟᱲᱤ ᱯᱟᱹᱨᱥᱤ ᱨᱮᱱᱟᱜ ᱟᱯᱱᱟᱨ ᱪᱤᱠᱤ ᱠᱟᱱᱟ ᱾", "Educational Heritage"),
    ("ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱟᱥᱲᱟ ᱨᱮ ᱯᱟᱲᱦᱟᱣ ᱟᱨ ᱚᱞ ᱠᱚ ᱪᱮᱫᱚᱜᱼᱟ ᱾", "Educational Classroom"),
    ("ᱫᱟᱜ ᱫᱚ ᱡᱤᱣᱤ ᱨᱮᱱᱟᱜ ᱢᱩᱬᱩᱛ ᱠᱟᱱᱟ, ᱱᱚᱶᱟ ᱵᱤᱱᱟᱹ ᱚᱠᱚᱭ ᱦᱚᱸ ᱵᱟᱠᱚ ᱵᱟᱧᱪᱟᱣ ᱫᱟᱲᱮᱭᱟᱜᱼᱟ ᱾", "Educational Science"),
    ("ᱯᱚᱸᱰᱤᱛ ᱨᱟᱹᱜᱷᱩᱱᱟᱛᱷ ᱢᱩᱨᱢᱩ ᱛᱟᱹᱠᱤᱱ ᱑᱙᱒᱕ ᱥᱟᱞᱮ ᱨᱮ ᱥᱟᱱᱛᱟᱲᱤ ᱯᱟᱹᱨᱥᱤ ᱞᱟᱹᱜᱤᱫ ᱚᱞ ᱪᱤᱠᱤ ᱠᱤᱱ ᱵᱮᱱᱟᱣ ᱞᱮᱫᱼᱟ ᱾", "Long History"),
    ("ᱟᱛᱳ ᱟᱥᱲᱟ ᱨᱮ ᱥᱮᱛᱟᱜ ᱵᱮᱲᱟ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱡᱚᱦᱟᱨ ᱠᱟᱛᱮ ᱟᱠᱚᱣᱟᱜ ᱠᱞᱟᱥ ᱨᱮ ᱯᱟᱲᱦᱟᱣ ᱠᱚ ᱮᱛᱚᱦᱚᱵᱟ ᱾", "Long Classroom"),
    ("ᱯᱚᱨᱤᱵᱮᱥ ᱵᱟᱧᱪᱟᱣ ᱞᱟᱹᱜᱤᱫ ᱟᱵᱚ ᱡᱚᱛᱚ ᱦᱚᱲ ᱫᱟᱨᱮ ᱨᱚᱦᱚᱭ ᱟᱨ ᱥᱟᱯᱷᱟ ᱫᱚᱦᱚ ᱨᱮ ᱢᱚᱱᱮ ᱮᱢ ᱦᱩᱭᱩᱜᱼᱟ ᱾", "Long Civic"),
    ("ᱫᱟᱭᱟ ᱠᱟᱛᱮ ᱟᱯᱱᱟᱨᱟᱜ ᱯᱩᱛᱷᱤ ᱨᱮᱱᱟᱜ ᱒᱕ ᱥᱟᱦᱴᱟ ᱡᱷᱤᱡ ᱢᱮ ᱟᱨ ᱯᱟᱲᱦᱟᱣ ᱢᱮ ᱾", "Educational Instructional"),
    ("ᱜᱟᱞᱚᱪᱤᱭᱟᱹ ᱡᱚᱠᱷᱚᱱ ᱵᱞᱟᱠᱵᱳᱨᱰ ᱨᱮ ᱚᱞ ᱠᱮᱫᱼᱟᱭ, ᱠᱷᱟᱱ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱟᱠᱚᱣᱟᱜ ᱠᱷᱟᱛᱟ ᱨᱮ ᱚᱞ ᱠᱚ ᱮᱛᱚᱦᱚᱵ ᱠᱮᱫᱼᱟ ᱾", "Complex Narrative")
]

results = {"hindi_to_english": [], "santali_to_english": []}

print("\n--- 1. Evaluating Hindi-to-English (20 Sentences) ---")
for i, (src, cat) in enumerate(hindi_sentences, 1):
    res = run_translation(src, src_lang="hin_Deva", tgt_lang="eng_Latn")
    print(f"[{i:02d}] ({cat}) '{src}'")
    print(f"     => '{res['text']}' [{res['total_ms']:.1f}ms, {res['token_count']} tok, dec={res['dec_ms']:.1f}ms]")
    assert len(res['text']) > 0, f"Empty output on sentence {i}"
    results["hindi_to_english"].append({
        "id": i, "category": cat, "source": src, "translation": res['text'],
        "total_ms": res['total_ms'], "token_count": res['token_count']
    })

print("\n--- 2. Evaluating Santali-to-English (20 Sentences) ---")
for i, (src, cat) in enumerate(santali_sentences, 1):
    res = run_translation(src, src_lang="sat_Olck", tgt_lang="eng_Latn")
    print(f"[{i:02d}] ({cat}) '{src}'")
    print(f"     => '{res['text']}' [{res['total_ms']:.1f}ms, {res['token_count']} tok, dec={res['dec_ms']:.1f}ms]")
    assert len(res['text']) > 0, f"Empty output on sentence {i}"
    results["santali_to_english"].append({
        "id": i, "category": cat, "source": src, "translation": res['text'],
        "total_ms": res['total_ms'], "token_count": res['token_count']
    })

cur_ram, final_peak = tracemalloc.get_traced_memory()
tracemalloc.stop()

results["benchmark_summary"] = {
    "total_sentences": 40,
    "hindi_avg_ms": float(np.mean([x['total_ms'] for x in results["hindi_to_english"]])),
    "santali_avg_ms": float(np.mean([x['total_ms'] for x in results["santali_to_english"]])),
    "peak_traced_ram_mb": final_peak / 1024 / 1024,
    "all_non_empty": True
}

with open(r"C:\AnuvaadAI Anti\tests\automated_reports\INDIC_EN_BENCHMARK_RESULTS.json", "w", encoding="utf-8") as f:
    json.dump(results, f, ensure_ascii=False, indent=2)

print("\nBenchmark completed successfully! Saved to tests/automated_reports/INDIC_EN_BENCHMARK_RESULTS.json")
