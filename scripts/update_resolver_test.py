with open(r'C:\AnuvaadAI Anti\apps\mobile\android\app\src\test\kotlin\org\anuvaad\ai\anuvaadai\ModelPathResolverTest.kt', 'r', encoding='utf-8') as f:
    text = f.read()

test_to_add = '''    @Test
    fun testEssentialIndicEnFilesListContainsExpectedFiles() {
        assertEquals(9, ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.size)
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("encoder_model.onnx"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("encoder_model.onnx.data"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("decoder_model.onnx"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("decoder_shared.onnx.data"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("decoder_with_past_model.onnx"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("dict.SRC.json"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("dict.TGT.json"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("model.SRC"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("model.TGT"))
    }
}'''

text = text.replace('    }\n}', '    }\n\n' + test_to_add)

with open(r'C:\AnuvaadAI Anti\apps\mobile\android\app\src\test\kotlin\org\anuvaad\ai\anuvaadai\ModelPathResolverTest.kt', 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(text)

print('Updated ModelPathResolverTest.kt with Indic-En test')
