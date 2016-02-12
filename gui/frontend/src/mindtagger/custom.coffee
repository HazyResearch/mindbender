angular.module 'mindbender.mindtagger.custom', [
]

.service 'CustomUtils', () ->
    class CustomUtils
        getWordsArray: (text) =>
            obj = JSON.parse(text)
            tokens = []
            for sent_tokens in obj['conll']['tokens']
                for tok in sent_tokens
                    tokens.push tok
            tokens
		
        getTrueIndices: (text, label) =>
            obj = JSON.parse(text)
            indices = []
            for value, index in obj
                if value['true_tag'] == label
                    indices.push index
            indices

        getPredIndices: (text, label) =>
            obj = JSON.parse(text)
            indices = []
            for value, index in obj
                if value['pred_tag'] == label
                    indices.push index
            indices
    new CustomUtils

