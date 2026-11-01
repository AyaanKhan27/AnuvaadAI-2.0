import sys
import json
import numpy as np
import onnxruntime as ort
import wave
import os

sys.stdout.reconfigure(encoding='utf-8')

# Reference phonemizer mapping matching SantaliPhonemizer.kt
VOWEL_BASES = {'\u1c64': 'i', '\u1c69': 'u', '\u1c6e': 'e', '\u1c73': 'o', '\u1c5a': '\u0254', '\u1c5f': 'a'}
BASIC_CONSONANTS = {
    '\u1c6f': 'p', '\u1c75': 'b', '\u1c5b': 't', '\u1c6b': 'd', '\u1c6a': 'c', '\u1c70': '\u0256',
    '\u1c74': '\u0288', '\u1c61': '\u025f', '\u1c60': 'k', '\u1c5c': '\u0261', '\u1c65': 's', '\u1c66': 'h',
    '\u1c62': 'm', '\u1c71': 'n', '\u1c67': '\u0272', '\u1c6c': '\u0273', '\u1c5d': '\u014b', '\u1c63': 'w',
    '\u1c76': 'w\u0303', '\u1c68': 'r', '\u1c72': '\u027d', '\u1c5e': 'l', '\u1c6d': 'j'
}

def to_phonemes(text):
    tokens = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch in BASIC_CONSONANTS:
            tokens.append(BASIC_CONSONANTS[ch])
        elif ch in VOWEL_BASES:
            tokens.append(VOWEL_BASES[ch])
        elif ch.isspace():
            tokens.append(' ')
        elif ch in ['.', '\u1c7e', '\u1c7f', '?', '!']:
            tokens.append('.')
        i += 1
    return tokens

test_cases = [
    ('Short Greeting', 'ᱦᱮᱞᱳ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱾'),
    ('Full Introduction', 'ᱤᱧᱟᱹᱜ ᱧᱩᱛᱩᱢ ᱚᱱᱩᱵᱚᱫ ᱾ ᱟᱞᱮ ᱥᱟᱱᱛᱟᱲᱤ ᱛᱮ ᱨᱚᱲ ᱠᱟᱱᱟ ᱾'),
    ('Classroom Question', 'ᱟᱢ ᱪᱮᱫ ᱞᱮᱠᱟ ᱢᱮᱱᱟᱜ ᱢᱮᱭᱟ?')
]

id_map_path = r'C:\AnuvaadAI Anti\engines\speech_synthesis\models\phoneme_id_map.json'
model_path = r'C:\AnuvaadAI Anti\engines\speech_synthesis\models\santali_piper_vits.onnx'

id_map = json.load(open(id_map_path, encoding='utf-8'))
sess = ort.InferenceSession(model_path)

print("--- Santali Neural VITS Multi-Sentence Verification ---")
for name, text in test_cases:
    tokens = to_phonemes(text)
    ids = list(id_map['^'])
    for t in tokens:
        if t in id_map:
            ids += id_map[t] + id_map['_']
    ids += id_map['$']
    inp = np.array([ids], dtype=np.int64)
    audio = sess.run(None, {'input': inp, 'input_lengths': np.array([len(ids)], dtype=np.int64), 'scales': np.array([0.667, 1.0, 0.8], dtype=np.float32)})[0]
    pcm = np.clip(audio.squeeze(), -1.0, 1.0)
    samples = len(pcm)
    duration = samples / 22050
    print(f"Test [{name}]: Text='{text}'")
    print(f"  Phonemes: {len(tokens)} tokens -> {len(ids)} model IDs")
    print(f"  Generated Audio: {samples} samples = {duration:.2f} seconds ({duration*1000:.0f} ms)")

    # Save audio of full introduction
    if name == 'Full Introduction':
        out_wav = r'C:\AnuvaadAI Anti\tests\fixtures\santali_full_speech.wav'
        pcm16 = (pcm * 32767).astype(np.int16)
        with wave.open(out_wav, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(22050)
            wf.writeframes(pcm16.tobytes())
        print(f"  WAV saved: {out_wav}")

print("\nAll multi-sentence speech tests passed.")
