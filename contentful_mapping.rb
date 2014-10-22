#belongs_to = keep ID in current model
#has_one = add ID to belonged model
#many = add another table IDs to current model
#many_through = map join table, add IDs to current model

module ContentfulMapping

  MAPPING = {
      'UserWildeisenUnit' => {
          contentful: 'Unit',
          type: :entry,
          fields: {},
          links: {}
      },
      'UserWildeisenAlergicInfo' => {
          contentful: 'AlergicInfo',
          type: :entry,
          fields: {},
          links: {}
      },
      'UserWildeisenIngredient' => {
          contentful: 'Ingredient',
          type: :entry,
          fields: {
          },
          links: {
              belongs_to: ['UserWildeisenUnit']
          }
      },
      'UserWildeisenRecipe' => {
          contentful: 'Recipe',
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
                      through: 'UserWildeisenRecipeToIngredient'
                  }
              ]
          }
      },
      'UserWildeisenRecipeToIngredient' => {
          contentful: 'RecipeIngredient',
          type: :entry,
          fields: {},
          links: {
              belongs_to: ['UserWildeisenRecipe', 'UserWildeisenIngredient']
          }
      },
      'UserWildeisenRecipeToAlergicInfo' => {
          contentful: 'RecipeToAlergicInfo',
          fields: {
          },
          links: {
          }
      }
  }

end