#belongs_to = keep ID in current model
#has_one = add ID to belonged model
#many = add another table IDs to current model
#many_through = map join table, add IDs to current model

module ContentfulMapping

  MAPPING = {
      'UserWildeisenUnit' => {
          content_type: 'Unit',
          type: :entry,
          fields: {},
          links: {}
      },
      'UserWildeisenAlergicInfo' => {
          content_type: 'AlergicInfo',
          type: :entry,
          fields: {},
          links: {}
      },
      'UserWildeisenIngredient' => {
          content_type: 'Ingredient',
          type: :entry,
          fields: {
          },
          links: {
              belongs_to: ['UserWildeisenUnit']
          }
      },
      'UserWildeisenRecipe' => {
          content_type: 'Recipe',
          type: :entry,
          fields: {},
          links: {
              many_through: [
                  {
                      relation_to: 'UserWildeisenAlergicInfo',
                      primary_id: :recipe_id,
                      foreign_id: :alergic_info_id,
                      through: 'UserWildeisenRecipeToAlergicInfo'
                  }
              ],
              many: [
                  {
                      primary_id: :recipe_id,
                      relation_to: 'UserWildeisenRecipeToIngredient'
                  }
              ]
          }
      },
      'UserWildeisenRecipeToIngredient' => {
          content_type: 'RecipeIngredient',
          type: :entry,
          fields: {},
          links: {
              belongs_to: ['UserWildeisenRecipe', 'UserWildeisenIngredient']
          }
      },
      'UserWildeisenRecipeToAlergicInfo' => {
          content_type: 'RecipeToAlergicInfo',
          fields: {
          },
          links: {
          }
      }
  }

end