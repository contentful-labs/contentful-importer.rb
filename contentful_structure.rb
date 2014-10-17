module ContentfulStructure

  STRUCTURE = {
      'Ingredient' => {
          id: 'ingredient',
          note: 'Collection of ingredients',
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
              'RecipeToIngredient' => {
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
          id: 'recipe_to_ingredient',
          fields: {
              is_main_ingredient: 'Boolean',
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
      'AlegricInfo' => {
          id: 'alergic_info',
          fields: {
              name: 'Text',
              sequence: 'Integer',
          }

      }
  }

end

