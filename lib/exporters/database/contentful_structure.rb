module Contentful
  module Exporter
    module Database
      module ContentfulStructure

        STRUCTURE = {
            'Ingredient' => {
                id: 'ingredient',
                note: 'Collection of ingredients',
                displayField: :name,
                fields: {
                    name: 'Text',
                    name_plural: 'Text',
                    description: 'Text',
                    active: 'Boolean',
                    'Unit' => {
                        id: 'unit',
                        link_type: 'Entry',
                    }
                }
            },
            'Recipe' => {
                id: 'recipe',
                displayField: :name,
                fields: {
                    random: 'Number',
                    name: 'Text',
                    description: 'Text',
                    active: 'Boolean',
                    visibility: 'Integer',
                    duration: 'Integer',
                    recipe_of_day_exclude: 'Boolean',
                    validated: 'Boolean',
                    clicks: 'Integer',
                    date_start: 'Date',
                    date_stop: 'Date',
                    'AlergicInfo' => {
                        id: 'alergic_infos',
                        link_type: 'Array',
                        type: 'Entry'
                    },
                    'RecipeIngredient' => {
                        id: 'recipe_ingredients',
                        link_type: 'Array',
                        type: 'Entry'
                    }
                }
            },
            'Unit' => {
                id: 'unit',
                fields: {
                    name: 'Text',
                    description: 'Text',
                    liquid: 'Boolean',
                    standardunits: 'Number',
                }
            },
            'RecipeIngredient' => {
                id: 'recipe_ingredient',
                fields: {
                    is_main_ingredient: 'Integer',
                    subtitle: 'Text',
                    sequence: 'Integer',
                    amount: 'Number',
                    info: 'Text',
                    old_pre_postfix: 'Text',
                    'Unit' => {
                        id: 'unit',
                        link_type: 'Entry',
                    },
                    'Recipe' => {
                        id: 'recipe',
                        link_type: 'Entry'
                    },
                    'Ingredient' => {
                        id: 'ingredient',
                        link_type: 'Entry'
                    }
                }
            },
            'AlergicInfo' => {
                id: 'alergic_info',
                fields: {
                    name: 'Text',
                    sequence: 'Integer',
                }

            }
        }

      end
    end
  end
end

