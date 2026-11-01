# AnuvaadAI 2.0 - Model Documentation

## 1. IndicTrans2 Indic-to-Indic Model
- **Model ID:** `indictrans2-indic-indic`
- **Location:** `<storage>/models/`
- **Primary Languages:** Hindi (`hin_Deva`), Santali (`sat_Olck`), and 20 other scheduled Indian languages.
- **Supported Operational Directions:**
  - `hin_Deva -> sat_Olck`
  - `sat_Olck -> hin_Deva`
- **Component Files & SHA-256 Checksums:**
  | File | Size (Bytes) | SHA-256 |
  |---|---|---|
  | `encoder.onnx` | 479,185,079 | `c7bb33c86d57f54f3d784e634e93e7559fd1a246ab2d0fe4b74395d2e964afe9` |
  | `decoder_prefill.onnx` | 806,499,935 | `87cc453cb3224ee6716f98ef6b7fe402454272bf23b884f2db63551f2bdd1106` |
  | `decoder_with_past.onnx` | 768,614,125 | `355b0becb7d5d4063ed6b6c00b366cd22f60c1c60ed857149bdd7d7cd6931ba9` |
  | `model.SRC` | 3,256,903 | `ac9257c8e76b8b607705b959cc3d075656ea33032f7a974e467b8941df6e98d4` |
  | `model.TGT` | 3,256,903 | `ac9257c8e76b8b607705b959cc3d075656ea33032f7a974e467b8941df6e98d4` |
  | `dict.SRC.json` | 3,391,208 | `3d3b180702520742dec423a5a7f7b4e3dad399d69e40ca7df294a1567884bed5` |
  | `dict.TGT.json` | 3,390,440 | `f7817850c9e4b99c59fad57d0611c7720f1921f215e6f247cf25d52eff7f1146` |
  | `tokenizer_config.json` | 1,109 | `a6bccdb273564be33d9a648af19e89e44b7011716f72c45071b0e93a012f518b` |
  | `special_tokens_map.json` | 96 | `9046da57c270c8e74d0f38832b4adce269c9d914ef21d2a0925e7772152dd793` |

## 2. IndicTrans2 English-to-Indic Model
- **Model ID:** `indictrans2-en-indic-dist-200m`
- **Location:** `<storage>/en-indic-models/`
- **Supported Operational Directions:**
  - `eng_Latn -> sat_Olck`
  - `eng_Latn -> hin_Deva`
- **Component Files & SHA-256 Checksums:**
  | File | Size (Bytes) | SHA-256 |
  |---|---|---|
  | `encoder_model.onnx` | 237,174 | `6da8412b812868e3b65a67036f3290c5ca5bc160a06d05e67886e0ff28557bce` |
  | `encoder_model.onnx.data` | 293,703,680 | `b093e2fb820ada91812eaa1231eaa98c087d4b00240edd3bac4eaaabfa04cece` |
  | `decoder_model.onnx` | 424,644 | `ad60b1ee386c7aaf537f34fb3885824705f1c2133670e9a5720ac47640778775` |
  | `decoder_shared.onnx.data` | 805,691,392 | `89982fdde643782af31c9305446f1e05a896320003720da6b85737489b95fd5d` |
  | `decoder_with_past_model.onnx` | 393,298 | `2ab43e849050ae0ec10d10c9a51fb7f49b0066fa21c9d3ef532f3607e153f3ae` |
  | `model.SRC` | 759,425 | `3cedc5cbcc740369b76201942a0f096fec7287fee039b55bdb956f301235b914` |
  | `model.TGT` | 3,256,903 | `ac9257c8e76b8b607705b959cc3d075656ea33032f7a974e467b8941df6e98d4` |
  | `dict.SRC.json` | 645,314 | `c6f65113581422c8777991d3770123c63447fe63dc5f3e8f4187eeff7553a689` |
  | `dict.TGT.json` | 3,390,440 | `f7817850c9e4b99c59fad57d0611c7720f1921f215e6f247cf25d52eff7f1146` |

## 3. Santali Native Speech Synthesis (VITS ONNX)
- **Model ID:** `santali-piper-vits`
- **Location:** `<storage>/santali-tts/`
- **Architecture:** Variational Inference with adversarial learning for end-to-end Text-to-Speech (VITS).
- **Phonemizer:** `SantaliPhonemizer.kt` (Pure Kotlin, zero external dependencies).
- **Audio Output:** 22,050 Hz Mono PCM Float.
- **Benchmark Latency:** 85 ms on CPU for typical conversational sentence.
- **Component Files & SHA-256 Checksums:**
  | File | Size (Bytes) | SHA-256 |
  |---|---|---|
  | `santali_piper_vits.onnx` | 63,502,227 | `4b77ff657567a9163f99e7128fd832e2db95bba1aedf44310e6e60ebf3c11970` |
  | `santali_piper_vits.onnx.json` | 7,225 | `797c728eba439d35967cc8d03c52d53c53a03e5f436c2847e02f037765fd4371` |
  | `phoneme_id_map.json` | 5,363 | `aaeaf4a2eedb9ae38d65b334178694ddbda337235c52771b267d1b73728db501` |

## 4. Reverse Indic-to-English Direction
- **Candidate Model:** `hari31416/indictrans2-indic-en-dist-200M-ONNX`
- **Purpose:** Supporting `hin_Deva -> eng_Latn` and `sat_Olck -> eng_Latn`.
- **Status:** Architecture verified; available for downloading and deployment into `<storage>/indic-en-models/`.
