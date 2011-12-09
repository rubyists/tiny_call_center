require 'yaml'

module TCC
  DICTIONARY = Innate::Helper::Localize::Dictionary.new
  DICTIONARY.load(:en, yaml: 'translation/en.yaml')
  DICTIONARY.load(:de, yaml: 'translation/de.yaml')
end
